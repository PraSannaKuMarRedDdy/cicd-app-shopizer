

resource "aws_codebuild_project" "java_dev_code_build" {
  name           = "JAVA-DEV-CODEBUILD"
  description    = "Java_CodeBuild_Project"
  build_timeout  = "20"
  queued_timeout = "20"

  service_role = aws_iam_role.java_dev_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

  }

  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_codedeploy_app" "java_codedeploy_app" {
  compute_platform = "Server"
  name             = "dev"
}

resource "aws_codedeploy_deployment_config" "java_codedeploy_deployment_config" {
  deployment_config_name = "java-dev-deployment-config"

  minimum_healthy_hosts {
    type  = "HOST_COUNT"
    value = 1
  }
}

resource "aws_codedeploy_deployment_group" "java_codedeploy_deployment_group" {
  app_name               = aws_codedeploy_app.java_codedeploy_app.name
  deployment_group_name  = "java-app-dev"
  service_role_arn       = aws_iam_role.java_dev_codedeploy_role.arn
  deployment_config_name = aws_codedeploy_deployment_config.java_codedeploy_deployment_config.id

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "java-app-instance"
  }
  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "Testapp-env"
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

resource "aws_codepipeline" "java_dev_codepipeline" {
  name     = "JAVA-DEV-CODEPIPELINE"
  role_arn = aws_iam_role.java_dev_codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit" #############Later on We have to check
      version          = "1"
      output_artifacts = ["javaapp_dev_source_output"]

      configuration = {
        "RepositoryName"       = "Hello-World-Pipeline"
        "BranchName"           = "master"
        "PollForSourceChanges" = "True"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["javaapp_dev_source_output"]
      output_artifacts = ["javaapp-dev-build-output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.java_dev_code_build.id
      }
    }
  }
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["javaapp-dev-build-output"]
      version         = "1"

      configuration = {
        ApplicationName = aws_codedeploy_app.java_codedeploy_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.java_codedeploy_deployment_group.deployment_group_name
      }
    }
  }
}

//locals {
//  webhook_secret = "super-secret"
//}
//
//resource "aws_codepipeline_webhook" "app_webhook" {
//  name            = "test-webhook-github-bar"
//  authentication  = "GITHUB_HMAC"
//  target_action   = "Source"
//  target_pipeline = aws_codepipeline.bar.name
//
//  authentication_configuration {
//    secret_token = local.webhook_secret
//  }
//
//  filter {
//    json_path    = "$.ref"
//    match_equals = "refs/heads/{Branch}"
//  }
//}
//
//# Wire the CodePipeline webhook into a GitHub repository.
//resource "github_repository_webhook" "bar" {
//  repository = github_repository.repo.name
//
//  name = "web"
//
//  configuration {
//    url          = aws_codepipeline_webhook.bar.url
//    content_type = "json"
//    insecure_ssl = true
//    secret       = local.webhook_secret
//  }
//
//  events = ["push"]
//}