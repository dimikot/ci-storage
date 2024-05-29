import time
from api_gh import gh_runner_ensure_absent
from helpers import AsgHandler, AsgSpec, Runner, RunnersRegistry, log


class HandlerOfflineRunners(AsgHandler):
    def __init__(self, *, asg_spec: AsgSpec, max_offline_age_sec: int):
        super().__init__(asg_spec=asg_spec)
        self.max_offline_age_sec = max_offline_age_sec
        self.offline_runners = RunnersRegistry()

    def handle(self, runners: list[Runner]) -> None:
        self.offline_runners.assign_if_not_exists(
            runner for runner in runners if runner.status == "offline"
        )
        for runner in self.offline_runners.values():
            if time.time() > runner.loaded_at + self.max_offline_age_sec:
                message = (
                    f"removing offline runner {runner.name} from {self.asg_spec}..."
                )
                try:
                    gh_runner_ensure_absent(
                        repository=self.asg_spec.repository,
                        runner_id=runner.id,
                    )
                    log(f"{message} done")
                except Exception as e:
                    log(f"{message} failed (will retry): {e}")
