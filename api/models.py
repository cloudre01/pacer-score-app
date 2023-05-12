from django.db import models


# Create your models here.
class Score(models.Model):
    user_id = models.CharField(max_length=100)
    score = models.IntegerField()
    dob = models.DateTimeField("date of birth", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user_id} - {self.score_value}"

    def length_of_name(self):
        return len(self.user_id)