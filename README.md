# scos-tf-security
Security stack that can be applied to any/all accounts


## Usage
Import the module into your manifest like so
```terraform
module "security" {
  source = "git@github.com:SmartColumbusOS/scos-tf-security.git?ref=1.0.0"
}
```

NOTE: you MUST enable recording for the generated AWS Config recorder via the AWS Console GUI, as terraform cannot do that for you. You only need to do this once.

NOTE: all services added by this module are only added to the region that your manifest specifies for the AWS provider. Ex. AWS Config only cares about the region you're in when you're in the AWS Console UI. The same applies for the terraform additions.

NOTE: due to the way SecurityHub and Config come up on creation SecurityHub will be slow to add its rules to Config. It will do it, it just takes time is all. If you want to speed things up, go to SecurityHub > Security Standards and disable and then re-enable the AWS Foundational and CIS standards, which will trigger them to add their Config rules immediately.

## Variables

- `force_destroy_s3_bucket` - Whether or not to destroy the S3 buckets in the stack when issuing a destroy. Default to `false`.
