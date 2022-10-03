CONTAINER_ID=$(docker ps | grep 'rapidpro:' | grep -v celery | awk '{print $1}')
docker exec -ti $CONTAINER_ID /rapidpro/env/bin/python ./manage.py createsuperuser
