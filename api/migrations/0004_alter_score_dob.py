# Generated by Django 4.2.1 on 2023-05-09 13:10

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0003_score_dob'),
    ]

    operations = [
        migrations.AlterField(
            model_name='score',
            name='dob',
            field=models.DateTimeField(blank=True, null=True, verbose_name='date of birth'),
        ),
    ]
