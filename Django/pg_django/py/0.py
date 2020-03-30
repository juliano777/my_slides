import os

from configobj import ConfigObj

# Database
# https://docs.djangoproject.com/en/2.2/ref/settings/#databases

# Database configuration file location
db_config_file = 'f{BASE_DIR}/{db.conf}'

# Read the configurations from file
db_config = ConfigObj(db_config_file)

# Database connection parameters

DB_HOST = db_config['DB_HOST']
DB_NAME = db_config['DB_NAME']
DB_USER = db_config['DB_USER']
DB_PASSWORD = db_config['DB_PASSWORD']
DB_PORT = db_config['DB_PORT']

DATABASES = {
             'default': {
                         'ENGINE': 'django.db.backends.postgresql',
                         'NAME': DB_NAME,
                         'USER': DB_USER,
                         'PASSWORD': DB_PASSWORD,
                         'HOST': DB_HOST,
                         'PORT': DB_PORT,
                         }
            }
