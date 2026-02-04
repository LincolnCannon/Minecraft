cd /Users/lincoln/Code/LincolnCannon/Minecraft/cdk
npm run build
npm run deploy

<<comment
General Instructions: https://github.com/doctorray117/minecraft-ondemand
Delete Instructions: delete the hosted zone A record in Route 53 first, then run "npm run destroy"
Settings Tasks: https://us-east-1.console.aws.amazon.com/datasync/home?region=us-east-1#/tasks
Settings Files: https://us-east-1.console.aws.amazon.com/s3/buckets/minecraft.metacannon.net?region=us-east-1&bucketType=general&tab=objects
UUID Lookup: https://mcuuid.net/
comment