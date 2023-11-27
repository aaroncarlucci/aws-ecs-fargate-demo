[
    {
        "name": "hello-world",
        "image": "${image}",
        "cpu": ${cpu},
        "memory": ${memory},
        "portMappings": [
            {
                "containerPort": 80,
                "hostPort": 80,
                "protocol": "tcp"
            }
        ],
        "essential": true,
            "environment": [],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "${log_group_name}",
                    "awslogs-region": "${log_group_region}",
                    "awslogs-stream-prefix": "${log_group_prefix}"
                }
            }
        }
]
