import argparse
import dataclasses
import http.server
import re
import shlex
import signal
import subprocess
import sys
import textwrap
import threading
import time
import traceback
from http import HTTPStatus
from json import dumps, loads, JSONDecodeError, decoder
from types import TracebackType
from typing import Any, Callable, Generic, Iterable, Literal, TypeVar


#
# Logs a timestamped message to stderr.
#
def log(msg: str):
    prefix = f"[{time.strftime('%d/%b/%Y %H:%M:%S')}] "
    print(re.sub("^", prefix, msg.rstrip(), flags=re.M), file=sys.stderr)


#
# Catches an exception in the context, logs it and continues the execution
# without re-raising.
#
def logged_exception(msg: str):
    class CatchAndLog:
        def __enter__(self):
            pass

        def __exit__(
            self,
            exc_type: type[BaseException] | None,
            exc_value: BaseException | None,
            tb: TracebackType | None,
        ):
            if exc_type and exc_value:
                log(
                    f"{msg}: {exc_type.__name__}: {exc_value}\n"
                    + "".join(traceback.format_tb(tb))
                )
                return True

    return CatchAndLog()


#
# A wrapper around subprocess.check_output that adds the content of stderr to
# the exception note (useful in e.g. unittest) and casts the output to str.
#
def check_output(
    args: list[str],
    input: str | None = None,
) -> str:
    try:
        return subprocess.check_output(
            args,
            stderr=subprocess.PIPE,
            input=input,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        if e.stderr:
            custom_error = CalledProcessError(e.returncode, e.cmd, e.output, e.stderr)
            custom_error.__traceback__ = e.__traceback__
            raise custom_error from None
        raise


#
# Wraps the main function to handle exceptions and exit with the proper code.
#
def wrap_main(main: Callable[[], Any]):
    def terminate(num: int, frame: Any):
        log(f"Received {signal.Signals(num).name}, exiting...")
        raise KeyboardInterrupt

    try:
        if threading.current_thread() is threading.main_thread():
            signal.signal(signal.SIGINT, terminate)
            signal.signal(signal.SIGTERM, terminate)
        main()
        sys.exit(0)
    except KeyboardInterrupt:
        sys.exit(1)
    except decoder.JSONDecodeError as e:
        log(f"{e}\nDoc: {e.doc if e.doc else '<empty>'}")
        sys.exit(2)
    except subprocess.CalledProcessError as e:
        log(
            f"$ {shlex.join(e.cmd).strip()}\n"
            + textwrap.indent(
                (
                    f"Error: command returned status {e.returncode}."
                    if e.returncode >= 0
                    else f"Command terminated with {signal.Signals(-e.returncode).name}."
                )
                + (f"\n{e.stdout}" if e.stdout else "")
                + (f"\n{e.stderr}" if e.stderr else ""),
                prefix="  ",
            ),
        )
        sys.exit(3)


#
# A custom exception class that includes the content of stderr in the message.
#
class CalledProcessError(subprocess.CalledProcessError):
    def __str__(self):
        msg = super().__str__()
        if self.stderr:
            stderr = re.sub(r"^\s*\n", "", self.stderr, flags=re.M)
            return f"{msg}\nSTDERR: {stderr}"
        return msg


#
# A helper class for ArgumentParser.
#
class ParagraphFormatter(argparse.HelpFormatter):
    def _fill_text(self, text: str, width: int, indent: str) -> str:
        text = re.sub(r"^ *\n", "", text)
        return "\n\n".join(
            [
                textwrap.indent(textwrap.fill(paragraph, width), indent)
                for paragraph in textwrap.dedent(text).split("\n\n")
            ]
        )


#
# One item of "repository:label:asg_name" specifications.
#
@dataclasses.dataclass(frozen=True)
class AsgSpec:
    repository: str
    label: str
    asg_name: str

    def __init__(self, asg: str):
        parts = asg.split(":")
        if len(parts) != 3:
            raise ValueError(f"Invalid ASG spec: {asg}")
        object.__setattr__(self, "repository", parts[0])
        object.__setattr__(self, "label", parts[1])
        object.__setattr__(self, "asg_name", parts[2])

    def __str__(self):
        return f"{self.repository}:{self.label}"


#
# An information about some registered Runner.
#
@dataclasses.dataclass
class Runner:
    id: str
    name: str
    status: Literal["online", "offline"]
    busy: bool
    labels: list[str]
    loaded_at: int

    def instance_id(self) -> str:
        match = re.match(r"^ci-storage-(\w+)", self.name)
        if not match:
            raise ValueError(f"Can't extract instance-id from runner name: {self.name}")
        return "i-" + match.group(1)


#
# A dict of Runner instances indexed by id.
#
class RunnersRegistry(dict[str, Runner]):
    def assign_if_not_exists(self, runners: Iterable[Runner]):
        ids = set(self.keys())
        for runner in runners:
            self.setdefault(runner.id, runner)
            ids.discard(runner.id)
        for id in ids:
            del self[id]


#
# A handling class for one auto-scaling group. A concrete derived class reacts
# on the list of runners (just fetched from GitHub API) related to this
# auto-scaling group (i.e. the runners in a particular repository labelled with
# a particular label).
#
class AsgHandler:
    def __init__(self, *, asg_spec: AsgSpec):
        self.asg_spec = asg_spec

    def __str__(self):
        return f"{self.__class__.__name__}({self.asg_spec})"

    def handle(self, runners: list[Runner]) -> None:
        raise NotImplementedError()


#
# An information about rate limits.
#
@dataclasses.dataclass
class RateLimits:
    limit: int
    remaining: int


#
# A tool subclass of BaseHTTPRequestHandler that allows to handle POST requests
# with JSON.
#
class PostJsonHttpRequestHandler(http.server.BaseHTTPRequestHandler):
    server_version = "ci-scaler"
    sys_version = "1.0"
    log_suffix = ""

    def handle_POST_json(self, data: dict[str, Any], data_bytes: bytes) -> None:
        self.send_error(404, "No handler for POST request overridden")
        pass

    def send_json(
        self,
        status: int,
        *,
        json: Any = None,
        message: str | None = None,
    ):
        if message:
            if json is None:
                json = {"message": message}
            self.log_suffix = (
                f"{self.log_suffix}; " if self.log_suffix else ""
            ) + message
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(f"{dumps(json)}\n".encode("utf-8"))

    # @override
    def log_request(self, code: Any = "-", size: Any = "-"):
        if isinstance(code, HTTPStatus):
            code = code.value
        self.log_message(
            '"%s" %s %s%s',
            self.requestline,
            str(code),
            str(size),
            f" {self.log_suffix}" if self.log_suffix else "",
        )

    # @override
    def do_POST(self):
        try:
            content_length = self.headers["Content-Length"] or "0"
            if not content_length.isdigit():
                self.send_error(400, "Content-Length header is invalid")
                return
            post_data = self.rfile.read(int(content_length)) or b"{}"
            data: dict[str, Any] | Any = loads(post_data)
            if not isinstance(data, dict):
                self.send_error(400, "Invalid JSON")
                return
            self.handle_POST_json(data, post_data)
        except JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return
        except BaseException:
            self.send_error(500, "Internal server error", traceback.format_exc())
            return

    # @override
    def send_error(
        self,
        code: int,
        message: str | None = None,
        explain: str | None = None,
    ):
        self.send_json(code, json={"error": message})
        log(f"Error: {message} (HTTP {code})")
        if explain:
            log(explain)


K = TypeVar("K")
V = TypeVar("V")


class ExpiringDict(Generic[K, V]):
    def __init__(self, *, ttl: float):
        self.ttl = ttl
        self._store: dict[K, V] = {}
        self._times: dict[K, float] = {}

    def _is_expired(self, key: K) -> bool:
        return time.time() - self._times.get(key, 0) > self.ttl

    def _garbage_collect(self) -> None:
        keys_to_delete = [key for key in self._store if self._is_expired(key)]
        for key in keys_to_delete:
            del self._store[key]
            del self._times[key]

    def __setitem__(self, key: K, value: V):
        self._garbage_collect()
        self._store[key] = value
        self._times[key] = time.time()

    def __getitem__(self, key: K) -> V:
        if key not in self._store or self._is_expired(key):
            raise KeyError(f"Key '{key}' not found or expired")
        return self._store[key]

    def __delitem__(self, key: K):
        if key in self._store:
            del self._store[key]
            del self._times[key]

    def __contains__(self, key: K):
        return key in self._store and not self._is_expired(key)

    def __repr__(self):
        return f"ExpiringDict({{k: v for k, v in self.store.items() if not self._is_expired(k)}})"

    def get(self, key: K, default: V | None = None) -> V | None:
        try:
            return self[key]
        except KeyError:
            return default
