from django.db.models import AutoField
from django.db.models import Model
from django.db.models import TextField


class Person(Model):
    '''
    Person Model

    Namespace: ns_hr
    Table: tb_person
    '''

    id_ = AutoField(db_column='id_', name='id', primary_key=True,)
    name = TextField(db_column='name', name='name',)
    surname = TextField(db_column='surname', name='surname',)

    def __str__(self):
        return f'{self.name} {self.surname}'

    class Meta:
        db_table = 'ns_hr"."tb_person'  # 'schema"."object'
        verbose_name_plural = 'Person'
