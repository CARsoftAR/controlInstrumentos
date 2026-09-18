from django.contrib import admin
from .models import Instrumento

@admin.register(Instrumento)
class InstrumentoAdmin(admin.ModelAdmin):
    list_display = ('codigo', 'nombre', 'estado') # Lo que verás en la lista
    search_fields = ('codigo', 'nombre')          # Para poder buscar