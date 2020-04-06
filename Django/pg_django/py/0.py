from human_resource.models.hr import Person

p = Person(name='Ludwig', surname='van Beethoven')

print(p)

p.save()   # Persist in database