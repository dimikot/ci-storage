from api_aws import (
    aws_autoscaling_describe_auto_scaling_group,
    aws_autoscaling_terminate_instance,
    aws_region,
    aws_cloudwatch_put_metric_data,
    aws_autoscaling_increment_desired_capacity,
)
from unittest import TestCase


class Test(TestCase):
    def test_aws_region(self):
        self.assertIsNone(aws_region())

    def test_aws_cloudwatch_put_metric_data(self):
        self.assertIsNone(
            aws_cloudwatch_put_metric_data(
                metrics={"Test": 42},
                dimensions={"Test": "Test"},
            )
        )

    def test_aws_autoscaling_describe_auto_scaling_group(self):
        self.assertIsNone(aws_autoscaling_describe_auto_scaling_group(asg_name="test"))

    def test_aws_autoscaling_increment_desired_capacity(self):
        self.assertIsNone(
            aws_autoscaling_increment_desired_capacity(asg_name="test", inc=1)
        )

    def test_aws_autoscaling_terminate_instance(self):
        self.assertIsNone(aws_autoscaling_terminate_instance(instance_id="test"))
