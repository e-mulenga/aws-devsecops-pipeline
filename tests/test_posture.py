import glob
import os
import re
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def read(*parts):
    with open(os.path.join(ROOT, *parts)) as handle:
        return handle.read()


def repo_files(suffixes=None):
    for path in glob.glob(os.path.join(ROOT, "**", "*"), recursive=True):
        if not os.path.isfile(path) or "__pycache__" in path or os.sep + "tests" + os.sep in path or path.endswith(".png"):
            continue
        if suffixes is None or path.endswith(suffixes):
            yield path


def tf_text():
    return "\n".join(read(os.path.relpath(p, ROOT)) for p in glob.glob(os.path.join(ROOT, "**", "*.tf"), recursive=True))


class PostureTests(unittest.TestCase):
    def test_no_landing_zone_resources_are_recreated(self):
        text = tf_text()
        for forbidden in (
            "aws_kms_key", "aws_vpc", "aws_ecr_repository", "aws_ecr_registry_scanning_configuration",
            "aws_iam_openid_connect_provider", "aws_route53_zone", "aws_acm_certificate", "aws_securityhub_account",
        ):
            self.assertNotIn(f'resource "{forbidden}"', text)

    def test_no_account_ids_in_repo_text(self):
        for path in repo_files((".tf", ".md", ".yml", ".sh", ".json", ".tfvars", ".example", ".py")):
            with open(path, errors="ignore") as handle:
                self.assertIsNone(re.search(r"(?<![0-9])[0-9]{12}(?![0-9])", handle.read()), path)

    def test_provider_file_not_versions_file(self):
        self.assertTrue(os.path.exists(os.path.join(ROOT, "provider.tf")))
        self.assertFalse(os.path.exists(os.path.join(ROOT, "versions.tf")))

    def test_pipeline_modules_run_in_ireland(self):
        main = read("main.tf")
        for module in ("pipeline_iam", "artifact_store", "codebuild", "notifications", "codepipeline", "codeartifact"):
            block = main.split(f'module "{module}"')[1].split("\n}\n")[0]
            self.assertIn("aws = aws.ireland", block, module)

    def test_no_kms_variable_remains(self):
        self.assertNotIn('variable "kms_key_arn"', tf_text())

    def test_landing_zone_contract_is_enforced(self):
        text = read("landing_zone.tf")
        self.assertIn("contract_schema_version", text)
        self.assertIn('default     = "2"', text)

    def test_buildspecs_log_in_to_the_landing_zone_registry_region(self):
        for path in glob.glob(os.path.join(ROOT, "buildspecs", "*.yml")):
            with open(path) as handle:
                text = handle.read()
            if "get-login-password" in text:
                self.assertIn("--region $ECR_REGION", text, path)
                self.assertNotIn("--region $AWS_REGION", text, path)

    def test_buildspecs_do_not_claim_security_hub_import(self):
        for path in glob.glob(os.path.join(ROOT, "buildspecs", "*.yml")):
            with open(path) as handle:
                self.assertNotIn("Security Hub", handle.read(), path)

    def test_only_terraform_is_referenced(self):
        banned = "to" + "fu"
        for path in repo_files():
            with open(path, errors="ignore") as handle:
                self.assertNotIn(banned, handle.read().lower(), path)


if __name__ == "__main__":
    unittest.main()
