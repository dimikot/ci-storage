import dataclasses
import math
import subprocess
import time
from api_aws import aws, aws_json
from json import dumps, loads
from typing import Any, Generic, Type, TypeVar

V = TypeVar("V")


#
# A dict-like class in memory with TTL-based expiration.
#
class MemoryDict(Generic[V]):
    def __init__(self, *, ttl: float):
        self.ttl = ttl
        self._store: dict[str, V] = {}
        self._times: dict[str, float] = {}

    def _is_expired(self, key: str) -> bool:
        return time.time() - self._times.get(key, 0) > self.ttl

    def _garbage_collect(self) -> None:
        keys_to_delete = [key for key in self._store if self._is_expired(key)]
        for key in keys_to_delete:
            del self._store[key]
            del self._times[key]

    def __setitem__(self, key: str, value: V):
        self._garbage_collect()
        self._store[key] = value
        self._times[key] = time.time()

    def __getitem__(self, key: str) -> V:
        if key not in self._store or self._is_expired(key):
            raise KeyError(f"Key '{key}' not found or expired")
        return self._store[key]

    def __delitem__(self, key: str):
        if key in self._store:
            del self._store[key]
            del self._times[key]

    def __contains__(self, key: str):
        return key in self._store and not self._is_expired(key)

    def __repr__(self):
        return (
            "MemoryDict("
            + str({k: v for k, v in self._store.items() if not self._is_expired(k)})
            + ")"
        )

    def get(self, key: str, default: V | None = None) -> V | None:
        try:
            return self[key]
        except KeyError:
            return default


#
# A dict-like class backed by DynamoDB with TTL-based expiration. Drop-in
# replacement for MemoryDict when shared state across instances is needed.
# Automatically creates the DynamoDB table if it doesn't exist.
#
class SharedDict(Generic[V]):
    def __init__(self, value_type: Type[V], *, ttl: float, table: str):
        self.ttl = ttl
        self.table = table
        self.value_type = value_type
        self._ensure_table()

    def _ensure_table(self) -> None:
        try:
            aws(
                "dynamodb",
                "describe-table",
                f"--table-name={self.table}",
            )
        except subprocess.CalledProcessError as e:
            if "ResourceNotFoundException" not in (e.stderr or ""):
                raise
            aws(
                "dynamodb",
                "create-table",
                f"--table-name={self.table}",
                "--attribute-definitions",
                "AttributeName=pk,AttributeType=S",
                "--key-schema",
                "AttributeName=pk,KeyType=HASH",
                "--billing-mode=PAY_PER_REQUEST",
            )
            for _ in range(60):
                res = aws_json(
                    "dynamodb",
                    "describe-table",
                    f"--table-name={self.table}",
                )
                if res and res["Table"]["TableStatus"] == "ACTIVE":
                    break
                time.sleep(5)
            aws(
                "dynamodb",
                "update-time-to-live",
                f"--table-name={self.table}",
                "--time-to-live-specification",
                "Enabled=true,AttributeName=ttl",
            )

    def __setitem__(self, key: str, value: V):
        ttl_epoch = math.floor(time.time() + self.ttl)
        item_json = dumps(
            {
                "pk": {"S": key},
                "val": {"S": dumps(value, default=_json_default)},
                "ttl": {"N": str(ttl_epoch)},
            }
        )
        aws(
            "dynamodb",
            "put-item",
            f"--table-name={self.table}",
            f"--item={item_json}",
        )

    def _deserialize(self, raw: Any) -> V:
        if dataclasses.is_dataclass(self.value_type) and isinstance(raw, dict):
            return self.value_type(**raw)
        else:
            return raw

    def _get_item(self, key: str) -> V | None:
        res = aws_json(
            "dynamodb",
            "get-item",
            f"--table-name={self.table}",
            f"--key={dumps({'pk': {'S': key}})}",
            "--consistent-read",
        )
        if res is None or "Item" not in res:
            return None
        item = res["Item"]
        ttl_val = int(item["ttl"]["N"])
        if ttl_val < time.time():
            return None
        return self._deserialize(loads(item["val"]["S"]))

    def __getitem__(self, key: str) -> V:
        value = self._get_item(key)
        if value is None:
            raise KeyError(f"Key '{key}' not found or expired")
        return value

    def __delitem__(self, key: str):
        aws(
            "dynamodb",
            "delete-item",
            f"--table-name={self.table}",
            f"--key={dumps({'pk': {'S': key}})}",
        )

    def __contains__(self, key: str):
        return self._get_item(key) is not None

    def __repr__(self):
        now = time.time()
        res = aws_json(
            "dynamodb",
            "scan",
            f"--table-name={self.table}",
            "--consistent-read",
        )
        items = {}
        if res and "Items" in res:
            for item in res["Items"]:
                ttl_val = int(item["ttl"]["N"])
                if ttl_val >= now:
                    items[item["pk"]["S"]] = self._deserialize(loads(item["val"]["S"]))
        return f"SharedDict({self.table}, {items})"

    def get(self, key: str, default: V | None = None) -> V | None:
        try:
            return self[key]
        except KeyError:
            return default


#
# Creates either MemoryDict or SharedDict instances depending on whether a
# DynamoDB table prefix is configured.
#
class StorageFactory:
    def __init__(self, *, dynamodb_table_prefix: str | None = None):
        self.dynamodb_table_prefix = dynamodb_table_prefix

    def create(
        self,
        value_type: Type[V],
        *,
        ttl: float,
        name: str,
    ) -> MemoryDict[V] | SharedDict[V]:
        if self.dynamodb_table_prefix is not None:
            return SharedDict[V](
                value_type,
                ttl=ttl,
                table=f"{self.dynamodb_table_prefix}-{name}",
            )
        else:
            return MemoryDict[V](ttl=ttl)


def _json_default(obj: Any) -> Any:
    if dataclasses.is_dataclass(obj) and not isinstance(obj, type):
        return dataclasses.asdict(obj)
    if isinstance(obj, set):
        return sorted(obj)
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")
