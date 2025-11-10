"""
Unit tests for ACEest Fitness Flask Application
"""

import pytest
import json
from app import app, users_data, workouts_data, calculate_bmi, calculate_bmr, calculate_calories

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    app.config['SECRET_KEY'] = 'test-secret-key'
    
    with app.test_client() as client:
        with app.app_context():
            # Clear test data
            users_data.clear()
            workouts_data.clear()
        yield client

@pytest.fixture
def registered_user(client):
    """Create a registered user for tests"""
    user_data = {
        'name': 'Test User',
        'regn_id': 'TEST001',
        'age': 25,
        'gender': 'M',
        'height': 175,
        'weight': 70
    }
    response = client.post('/register',
                          data=json.dumps(user_data),
                          content_type='application/json')
    return user_data

class TestHealthChecks:
    """Test health check and monitoring endpoints"""
    
    def test_health_endpoint(self, client):
        """Test /health endpoint"""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert 'timestamp' in data
        assert data['version'] == '2.0'
    
    def test_metrics_endpoint(self, client):
        """Test /metrics endpoint"""
        response = client.get('/metrics')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'total_users' in data
        assert 'total_workouts' in data
        assert 'timestamp' in data

class TestCalculations:
    """Test calculation helper functions"""
    
    def test_calculate_bmi(self):
        """Test BMI calculation"""
        bmi = calculate_bmi(70, 175)
        assert round(bmi, 2) == 22.86
    
    def test_calculate_bmr_male(self):
        """Test BMR calculation for male"""
        bmr = calculate_bmr(70, 175, 25, 'M')
        assert bmr == 1693.75
    
    def test_calculate_bmr_female(self):
        """Test BMR calculation for female"""
        bmr = calculate_bmr(60, 165, 30, 'F')
        assert bmr == 1356.25
    
    def test_calculate_calories(self):
        """Test calorie calculation"""
        calories = calculate_calories('Workout', 30, 70)
        assert round(calories, 1) == 220.5

class TestAuthentication:
    """Test user authentication flows"""
    
    def test_index_page(self, client):
        """Test home page loads"""
        response = client.get('/')
        assert response.status_code == 200
        assert b'Welcome to ACEest Fitness' in response.data
    
    def test_register_get(self, client):
        """Test registration page loads"""
        response = client.get('/register')
        assert response.status_code == 200
        assert b'Create Your Account' in response.data
    
    def test_register_post_success(self, client):
        """Test successful user registration"""
        user_data = {
            'name': 'John Doe',
            'regn_id': 'REG001',
            'age': 28,
            'gender': 'M',
            'height': 180,
            'weight': 75
        }
        response = client.post('/register',
                              data=json.dumps(user_data),
                              content_type='application/json')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
        assert 'bmi' in data
        assert 'bmr' in data
    
    def test_register_duplicate_user(self, client, registered_user):
        """Test registration with duplicate ID"""
        response = client.post('/register',
                              data=json.dumps(registered_user),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert data['success'] is False
    
    def test_register_missing_fields(self, client):
        """Test registration with missing fields"""
        incomplete_data = {
            'name': 'Test User',
            'regn_id': 'TEST002'
        }
        response = client.post('/register',
                              data=json.dumps(incomplete_data),
                              content_type='application/json')
        
        assert response.status_code == 400
    
    def test_login_success(self, client, registered_user):
        """Test successful login"""
        login_data = {'regn_id': registered_user['regn_id']}
        response = client.post('/login',
                              data=json.dumps(login_data),
                              content_type='application/json')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
    
    def test_login_nonexistent_user(self, client):
        """Test login with non-existent user"""
        login_data = {'regn_id': 'NONEXISTENT'}
        response = client.post('/login',
                              data=json.dumps(login_data),
                              content_type='application/json')
        
        assert response.status_code == 404
    
    def test_logout(self, client, registered_user):
        """Test logout functionality"""
        # Login first
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        response = client.get('/logout', follow_redirects=True)
        assert response.status_code == 200

class TestWorkoutManagement:
    """Test workout tracking functionality"""
    
    def test_add_workout_success(self, client, registered_user):
        """Test adding a workout session"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        workout_data = {
            'category': 'Workout',
            'exercise': 'Push-ups',
            'duration': 30
        }
        response = client.post('/api/workout/add',
                              data=json.dumps(workout_data),
                              content_type='application/json')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
        assert 'calories' in data
    
    def test_add_workout_invalid_duration(self, client, registered_user):
        """Test adding workout with invalid duration"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        workout_data = {
            'category': 'Workout',
            'exercise': 'Running',
            'duration': -10
        }
        response = client.post('/api/workout/add',
                              data=json.dumps(workout_data),
                              content_type='application/json')
        
        assert response.status_code == 400
    
    def test_workout_summary(self, client, registered_user):
        """Test workout summary endpoint"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        # Add a workout first
        workout_data = {
            'category': 'Workout',
            'exercise': 'Squats',
            'duration': 20
        }
        client.post('/api/workout/add',
                   data=json.dumps(workout_data),
                   content_type='application/json')
        
        response = client.get('/api/workout/summary')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'total_time' in data
        assert 'total_calories' in data
        assert data['total_time'] == 20
    
    def test_workout_progress(self, client, registered_user):
        """Test workout progress data endpoint"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        response = client.get('/api/workout/progress')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'categories' in data
        assert 'durations' in data
        assert 'calories' in data

class TestPages:
    """Test page rendering"""
    
    def test_dashboard_requires_login(self, client):
        """Test dashboard redirects when not logged in"""
        response = client.get('/dashboard', follow_redirects=False)
        assert response.status_code == 302  # Redirect
    
    def test_dashboard_with_login(self, client, registered_user):
        """Test dashboard loads when logged in"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
            sess['user_name'] = registered_user['name']
        
        response = client.get('/dashboard')
        assert response.status_code == 200
        assert b'Welcome' in response.data
    
    def test_workout_plan_page(self, client, registered_user):
        """Test workout plan page"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        response = client.get('/workout-plan')
        assert response.status_code == 200
        assert b'Workout Plan' in response.data
    
    def test_diet_guide_page(self, client, registered_user):
        """Test diet guide page"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        response = client.get('/diet-guide')
        assert response.status_code == 200
        assert b'Diet Guide' in response.data
    
    def test_404_error(self, client):
        """Test 404 error handler"""
        response = client.get('/nonexistent-page')
        assert response.status_code == 404
        assert b'404' in response.data

class TestAPIEndpoints:
    """Test API functionality"""
    
    def test_user_profile(self, client, registered_user):
        """Test user profile API"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        response = client.get('/api/user/profile')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['name'] == registered_user['name']
        assert data['regn_id'] == registered_user['regn_id']

class TestWorkoutCategories:
    """Test different workout categories"""
    
    def test_warmup_category(self, client, registered_user):
        """Test warm-up workout"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        workout_data = {
            'category': 'Warm-up',
            'exercise': 'Jogging',
            'duration': 10
        }
        response = client.post('/api/workout/add',
                              data=json.dumps(workout_data),
                              content_type='application/json')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
    
    def test_cooldown_category(self, client, registered_user):
        """Test cool-down workout"""
        with client.session_transaction() as sess:
            sess['user_id'] = registered_user['regn_id']
        
        workout_data = {
            'category': 'Cool-down',
            'exercise': 'Stretching',
            'duration': 5
        }
        response = client.post('/api/workout/add',
                              data=json.dumps(workout_data),
                              content_type='application/json')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True

if __name__ == '__main__':
    pytest.main(['-v', '--cov=app', '--cov-report=html', '--cov-report=term'])
