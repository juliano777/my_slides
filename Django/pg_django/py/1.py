# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Custom Apps
    'human_resource',
]

from human_resource.models.hr import Person

p = Person(name='Ludwig', surname='van Beethoven')

print(p)

p.save()   # Persist in database