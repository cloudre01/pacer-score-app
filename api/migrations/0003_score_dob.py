# Generated by Django 4.2.1 on 2023-05-05 09:11

from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0002_score_created_at'),
    ]

    operations = [
        migrations.AddField(
            model_name='score',
            name='dob',
            field=models.DateTimeField(default=django.utils.timezone.now, verbose_name='date of birth'),
            preserve_default=False,
        ),
    ]
