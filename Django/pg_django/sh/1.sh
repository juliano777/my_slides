cd src

tree .

manage.py migrate

manage.py createsuperuser

manage.py startapp human_resource

vim my_project/settings.py

mkdir human_resource/models

rm -f human_resource/models.py

vim human_resource/models/hr.py

vim human_resource/models/__init__.py

manage.py makemigrations human_resource

manage.py migrate --fake

tree human_resource/

manage.py shell

manage.py dbshell
