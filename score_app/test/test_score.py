import json

from django.test import TestCase, Client
from rest_framework import status

from api.models import Score


class GetScoreTest(TestCase):

    def setUp(self):
        self.client = Client()
        self.user_id = 'testuser'
        self.score_value = 10
        self.valid_payload = json.dumps({
            'user_id': self.user_id,
            'score': self.score_value
        })
        self.invalid_payload = json.dumps({
            'user_id': '',
            'score': ''
        })

    def test_post_valid_payload(self):
        response = self.client.post('/api/get_score/', data=self.valid_payload, content_type='application/json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['score'], 11)
        score_obj = Score.objects.get(user_id=self.user_id, score=self.score_value + 1)
        self.assertIsNotNone(score_obj)

    def test_fail_get_score(self):
        response = self.client.post('/api/get_score/', data=self.invalid_payload, content_type='application/json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.json()['score'][0], 'A valid integer is required.')

    def test_post_missing_user_id(self):
        payload = {
            'score': self.score_value
        }
        response = self.client.post('/api/get_score/', data=payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.json(), {'user_id': ['This field is required.']})

    def test_post_missing_score_value(self):
        payload = {
            'user_id': self.user_id
        }
        response = self.client.post('/api/get_score/', data=payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.json(), {'score': ['This field is required.']})

    def test_post_invalid_score_value(self):
        payload = {
            'user_id': self.user_id,
            'score': 'abc'
        }
        response = self.client.post('/api/get_score/', data=payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.json(), {'score': ['A valid integer is required.']})
