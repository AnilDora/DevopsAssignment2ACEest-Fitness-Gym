"""
ACEest Fitness & Gym Management System - Flask Web Application
Version: 2.0 (Refactored from Tkinter to Flask)
"""

from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from datetime import datetime, date, timedelta
import os
import json
from functools import wraps

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# MET Values for calorie calculation
MET_VALUES = {
    "Warm-up": 3,
    "Workout": 6,
    "Cool-down": 2.5
}

# In-memory storage (replace with database in production)
users_data = {}
workouts_data = {}

# Helper functions
def calculate_bmi(weight_kg, height_cm):
    """Calculate Body Mass Index"""
    return weight_kg / ((height_cm / 100) ** 2)

def calculate_bmr(weight_kg, height_cm, age, gender):
    """Calculate Basal Metabolic Rate using Mifflin-St Jeor Equation"""
    if gender.upper() == 'M':
        return 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:
        return 10 * weight_kg + 6.25 * height_cm - 5 * age - 161

def calculate_calories(category, duration_min, weight_kg):
    """Calculate calories burned during exercise"""
    met = MET_VALUES.get(category, 5)
    return (met * 3.5 * weight_kg / 200) * duration_min

def get_user_id():
    """Get current user ID from session"""
    return session.get('user_id', 'guest')

def login_required(f):
    """Decorator to require login"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return decorated_function

# Routes
@app.route('/')
def index():
    """Home page"""
    return render_template('index.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    """User registration"""
    if request.method == 'POST':
        data = request.get_json()
        
        try:
            name = data['name']
            regn_id = data['regn_id']
            age = int(data['age'])
            gender = data['gender'].upper()
            height_cm = float(data['height'])
            weight_kg = float(data['weight'])
            
            # Check if user already exists
            if regn_id in users_data:
                return jsonify({'success': False, 'message': 'User already registered'}), 400
            
            # Calculate BMI and BMR
            bmi = calculate_bmi(weight_kg, height_cm)
            bmr = calculate_bmr(weight_kg, height_cm, age, gender)
            
            # Store user data
            users_data[regn_id] = {
                'name': name,
                'regn_id': regn_id,
                'age': age,
                'gender': gender,
                'height': height_cm,
                'weight': weight_kg,
                'bmi': round(bmi, 2),
                'bmr': round(bmr, 0),
                'registered_date': datetime.now().isoformat()
            }
            
            # Initialize workout data for user
            workouts_data[regn_id] = {
                'Warm-up': [],
                'Workout': [],
                'Cool-down': []
            }
            
            # Set session
            session['user_id'] = regn_id
            session['user_name'] = name
            
            return jsonify({
                'success': True,
                'message': 'Registration successful!',
                'bmi': round(bmi, 2),
                'bmr': round(bmr, 0)
            })
            
        except KeyError as e:
            return jsonify({'success': False, 'message': f'Missing field: {str(e)}'}), 400
        except ValueError as e:
            return jsonify({'success': False, 'message': f'Invalid data: {str(e)}'}), 400
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login"""
    if request.method == 'POST':
        data = request.get_json()
        regn_id = data.get('regn_id')
        
        if regn_id in users_data:
            session['user_id'] = regn_id
            session['user_name'] = users_data[regn_id]['name']
            return jsonify({'success': True, 'message': 'Login successful!'})
        else:
            return jsonify({'success': False, 'message': 'User not found. Please register.'}), 404
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """User logout"""
    session.clear()
    return redirect(url_for('index'))

@app.route('/dashboard')
@login_required
def dashboard():
    """Main dashboard"""
    user_id = get_user_id()
    user = users_data.get(user_id, {})
    return render_template('dashboard.html', user=user)

@app.route('/api/workout/add', methods=['POST'])
@login_required
def add_workout():
    """Add a workout session"""
    user_id = get_user_id()
    data = request.get_json()
    
    try:
        category = data['category']
        exercise = data['exercise']
        duration = int(data['duration'])
        
        if duration <= 0:
            return jsonify({'success': False, 'message': 'Duration must be positive'}), 400
        
        # Get user weight for calorie calculation
        weight = users_data.get(user_id, {}).get('weight', 70)
        calories = calculate_calories(category, duration, weight)
        
        workout_entry = {
            'exercise': exercise,
            'duration': duration,
            'calories': round(calories, 1),
            'timestamp': datetime.now().isoformat(),
            'date': date.today().isoformat()
        }
        
        workouts_data[user_id][category].append(workout_entry)
        
        return jsonify({
            'success': True,
            'message': f'{exercise} added successfully!',
            'calories': round(calories, 1)
        })
        
    except KeyError as e:
        return jsonify({'success': False, 'message': f'Missing field: {str(e)}'}), 400
    except ValueError as e:
        return jsonify({'success': False, 'message': f'Invalid data: {str(e)}'}), 400

@app.route('/api/workout/summary')
@login_required
def workout_summary():
    """Get workout summary"""
    user_id = get_user_id()
    workouts = workouts_data.get(user_id, {'Warm-up': [], 'Workout': [], 'Cool-down': []})
    
    summary = {
        'categories': {},
        'total_time': 0,
        'total_calories': 0,
        'session_count': 0
    }
    
    for category, sessions in workouts.items():
        category_time = sum(s['duration'] for s in sessions)
        category_calories = sum(s['calories'] for s in sessions)
        
        summary['categories'][category] = {
            'count': len(sessions),
            'total_time': category_time,
            'total_calories': round(category_calories, 1),
            'sessions': sessions
        }
        
        summary['total_time'] += category_time
        summary['total_calories'] += category_calories
        summary['session_count'] += len(sessions)
    
    summary['total_calories'] = round(summary['total_calories'], 1)
    
    return jsonify(summary)

@app.route('/api/workout/progress')
@login_required
def workout_progress():
    """Get workout progress data for charts"""
    user_id = get_user_id()
    workouts = workouts_data.get(user_id, {'Warm-up': [], 'Workout': [], 'Cool-down': []})
    
    progress_data = {
        'categories': [],
        'durations': [],
        'calories': []
    }
    
    for category, sessions in workouts.items():
        total_duration = sum(s['duration'] for s in sessions)
        total_calories = sum(s['calories'] for s in sessions)
        
        if total_duration > 0:  # Only include categories with data
            progress_data['categories'].append(category)
            progress_data['durations'].append(total_duration)
            progress_data['calories'].append(round(total_calories, 1))
    
    return jsonify(progress_data)

@app.route('/api/user/profile')
@login_required
def user_profile():
    """Get user profile"""
    user_id = get_user_id()
    user = users_data.get(user_id, {})
    return jsonify(user)

@app.route('/workout-plan')
@login_required
def workout_plan():
    """Workout plan page"""
    return render_template('workout_plan.html')

@app.route('/diet-guide')
@login_required
def diet_guide():
    """Diet guide page"""
    return render_template('diet_guide.html')

@app.route('/health')
def health_check():
    """Health check endpoint for monitoring"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '2.0'
    })

@app.route('/metrics')
def metrics():
    """Metrics endpoint for monitoring"""
    return jsonify({
        'total_users': len(users_data),
        'total_workouts': sum(len(w['Warm-up']) + len(w['Workout']) + len(w['Cool-down']) 
                             for w in workouts_data.values()),
        'timestamp': datetime.now().isoformat()
    })

@app.errorhandler(404)
def not_found(error):
    """404 error handler"""
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    """500 error handler"""
    return render_template('500.html'), 500

if __name__ == '__main__':
    # Run the application
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    app.run(host='0.0.0.0', port=port, debug=debug)
