variable "exclusion_rule_count" {
  description = "The number of GuardDuty exclusion rules to apply"
  default     = 0
}

variable "exclusion_rules" {
  description = "The basic details for GuardDuty exclusion rules"
  type        = list(string)
  default     = []
  /*
   Should be maps in this example form (note that criterion must be a json string b/c tf 0.11.0 does not deal with nested maps well):
   {"name" = "one", "description" = "one", "criterion" = jsonencode({"severity" = {"Gte" = 0}, "region" = {"Eq" = ["us-west-2", "us-east-2"]}})}

   see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-guardduty-filter.html
   and https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-guardduty-filter-condition.html
  */
}

resource "aws_guardduty_detector" "default" {
  enable = true
}

resource "aws_cloudformation_stack" "guard_duty_exclusions" {
  count = var.exclusion_rule_count
  name  = "guard-duty-exclusion-${terraform.workspace}-${count.index}"
  template_body = <<EOF
---
AWSTemplateFormatVersion: "2010-09-09"
Description: Terraform-managed CF Stack for GuardDuty suppression/exclusion/filter rules
Resources:
  Exclusion:
    Type: AWS::GuardDuty::Filter
    Properties:
      Action: ARCHIVE
      Name: ${lookup(
        var.exclusion_rules[count.index],
        "name",
        "${terraform.workspace}-rule-${count.index}",
      )}
      Description: ${lookup(
        var.exclusion_rules[count.index],
        "description",
        "${terraform.workspace}-rule-description-${count.index}",
      )}
      DetectorId: ${aws_guardduty_detector.default.id}
      FindingCriteria:
        Criterion: ${lookup(var.exclusion_rules[count.index], "criterion", "{}")}
      Rank: ${count.index + 1}
EOF

}

