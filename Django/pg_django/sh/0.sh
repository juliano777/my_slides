psql

virtualenv -p `which python3.8` django

cd django && source bin/activate

pip install django psycopg2-binary configobj ipython

django-admin startproject my_project

mv my_project src

cat < src/my_project/db.conf
DB_HOST = 'localhost'
DB_NAME = 'db_test'
DB_USER = 'user_test'
DB_PASSWORD = '123'
DB_PORT = 5432
EOF

vim src/my_project/settings.py

ln -s `pwd`/src/manage.py `pwd`/bin/manage.py

manage.py runserver 0.0.0.0:8000
