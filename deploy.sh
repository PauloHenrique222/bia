./build.sh
aws ecs update-service --cluster custer-bia-alb --service service-bia-alb --force-new-deployment
