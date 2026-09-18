from django.db import models

class Operario(models.Model):
    nombre = models.CharField(max_length=100)
    legajo = models.CharField(max_length=20, unique=True)
    cargo = models.CharField(max_length=50, blank=True, null=True)
    activo = models.BooleanField(default=True)

    def __str__(self):
        return self.nombre
