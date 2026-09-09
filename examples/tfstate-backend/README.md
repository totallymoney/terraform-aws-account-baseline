# State backend

Creates the encrypted S3 bucket, CMK, access log bucket and lock table that
every other stack in the account uses for state.

Change `bucket_name` to something globally unique before applying.

Apply this first, with local state. Once it exists, add the backend block and
run `terraform init -migrate-state` to move this stack's own state into it.
