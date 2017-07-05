from flask import Flask, redirect, url_for, request, render_template, jsonify, abort
from flask_restful import Resource, Api
from sqlalchemy import create_engine
from json import dumps


e = create_engine('mysql://root:p@$$w0rd@localhost/test')
app = Flask(__name__)
api = Api(app)

@app.route('/', methods=['POST','GET'])
def index():
	return render_template('index.html')




class SendQuery(object):

	def getJson(self, sql):
		conn = e.connect()
		query = conn.execute(sql)
		result = {'data': [ dict( zip( tuple (query.keys() ) ,i ) ) for i in query.cursor ]}
		return result
		

class Disaster_Summary(Resource, SendQuery):
	def get(self, start_date, end_date):
		try:	
			sql = ''' 
				SELECT STATE,
					ROUND(SUM(DAMAGE_PROPERTY)/1000000,3) DAMAGE_PROPERTY,
					ROUND(SUM(DAMAGE_CROPS)/1000000,3) DAMAGE_CROPS,
					CAST(SUM(INJURIES_INDIRECT) AS UNSIGNED) INJURIES_INDIRECT,
					CAST(SUM(INJURIES_DIRECT) AS UNSIGNED) INJURIES_DIRECT,
				    CAST(SUM(DEATHS_INDIRECT) AS UNSIGNED) DEATHS_INDIRECT,
				    CAST(SUM(DEATHS_DIRECT) AS UNSIGNED) DEATHS_DIRECT
				FROM FT_DISASTER_SUMMARY 
				WHERE BEGIN_DATE BETWEEN '{}' AND '{}'
				AND STATE IN (SELECT f_compute_state(NAME)  END FROM STATE)
				GROUP BY STATE
				ORDER BY 2 DESC, 3 DESC, 4 DESC
				LIMIT 10
			'''.format(start_date,end_date)
			return self.getJson(sql)

		except Exception as e:
			abort(400, requestCode=400, message="something went wrong Check parameters to be sure")


class Damaging_Events(Resource, SendQuery):
	def get(self, start_date, end_date, state):
		try:	
			sql = '''
				SELECT EVENT_TYPE, 
					ROUND(SUM(DAMAGE_PROPERTY)/1000000,3)DAMAGE_PROPERTY, 
					ROUND(SUM(DAMAGE_CROPS)/1000000,3)DAMAGE_CROPS
				FROM FT_DISASTER_SUMMARY
				WHERE BEGIN_DATE BETWEEN '{}' AND '{}'
				AND STATE = f_compute_state('{}')
				GROUP BY EVENT_TYPE
				ORDER BY 2 DESC
				LIMIT 5
			'''.format(start_date, end_date, state)
			return self.getJson(sql)

		except Exception as e:
			abort(400, requestCode=400, message="something went wrong Check parameters to be sure")

class Daily_Damage(Resource, SendQuery):
	def get(self, start_date, end_date, state):
		try:	
			sql= '''
				SELECT BEGIN_DATE, 
					ROUND(SUM(DAMAGE_PROPERTY)/1000000,3)DAMAGE_PROPERTY, 
					ROUND(SUM(DAMAGE_CROPS)/1000000,3)DAMAGE_CROPS
				FROM FT_DISASTER_SUMMARY
				WHERE BEGIN_DATE BETWEEN '{}' AND '{}'
				AND STATE = f_compute_state('{}')
				GROUP BY BEGIN_DATE
				ORDER BY 1 ASC
			'''.format(start_date, end_date, state)
			return self.getJson(sql)

		except Exception as e:
			abort(400, requestCode=400, message="something went wrong Check parameters to be sure")

class List_States(Resource, SendQuery):
	def get(self):
		try:	
			sql= '''
				SELECT NAME
				FROM STATE
				WHERE TYPE <> 'minor'
				ORDER BY ID
			'''
			return self.getJson(sql)

		except Exception as e:
			abort(400, requestCode=400, message="something went wrong Check parameters to be sure")

class Injury_Death(Resource, SendQuery):
	def get(self, start_date, end_date, state):
		try:	
			sql= ''' 
			SELECT CAST(SUM(INJURIES_INDIRECT) AS UNSIGNED) INJURIES_INDIRECT,
				CAST(SUM(INJURIES_DIRECT) AS UNSIGNED) INJURIES_DIRECT,
			    CAST(SUM(DEATHS_INDIRECT) AS UNSIGNED) DEATHS_INDIRECT,
			    CAST(SUM(DEATHS_DIRECT) AS UNSIGNED) DEATHS_DIRECT
			FROM `FT_DISASTER_SUMMARY`
			WHERE BEGIN_DATE BETWEEN '{}' AND '{}'
			AND STATE = f_compute_state('{}')
			'''.format(start_date, end_date, state)
			return self.getJson(sql)

		except Exception as e:
			abort(400, requestCode=400, message="something went wrong Check parameters to be sure")
			

class Top_Casualties(Resource, SendQuery):
	def get(self, start_date, end_date):

		try:
			sql = ''' 
				SELECT STATE,
				    CAST(SUM(DEATHS_DIRECT) AS UNSIGNED) DEATHS_DIRECT,
				    CAST(SUM(DEATHS_INDIRECT) AS UNSIGNED) DEATHS_INDIRECT,
					CAST(SUM(INJURIES_DIRECT) AS UNSIGNED) INJURIES_DIRECT,
					CAST(SUM(INJURIES_INDIRECT) AS UNSIGNED) INJURIES_INDIRECT
				FROM FT_DISASTER_SUMMARY 
				WHERE BEGIN_DATE BETWEEN '{}' AND '{}'
				AND STATE IN (SELECT f_compute_state(NAME)  END FROM STATE)
				GROUP BY STATE
				ORDER BY 2 DESC, 3 DESC, 4 DESC
				LIMIT 10
			'''.format(start_date,end_date)
			return self.getJson(sql)

		except Exception as e:
			abort(400, requestCode=400, message="something went wrong Check parameters to be sure")


api.add_resource(Disaster_Summary, '/api/summary/<int:start_date>/<int:end_date>/', methods=['GET', 'POST'])
api.add_resource(Damaging_Events, '/api/events/<int:start_date>/<int:end_date>/<string:state>/', methods=['GET', 'POST'])
api.add_resource(Daily_Damage, '/api/daily_damage/<int:start_date>/<int:end_date>/<string:state>/', methods=['GET', 'POST'])
api.add_resource(List_States, '/api/list_states/')
api.add_resource(Injury_Death, '/api/injury_death/<int:start_date>/<int:end_date>/<string:state>/', methods=['GET', 'POST'])
api.add_resource(Top_Casualties, '/api/top_casualties/<int:start_date>/<int:end_date>/', methods=['GET', 'POST'])


if __name__ == '__main__':
	app.run(debug = True)

# @app.route('/api/summary/<int:start_date>/<int:end_date>/', methods=['GET', 'POST'])
# def getData(start_date, end_date):

# 	if request.method == 'GET':

# 		sql = '''
# 			SELECT STATE, 
# 			ROUND(SUM(DAMAGE_PROPERTY)/1000000,2)DAMAGE_PROPERTY
# 		FROM FT_DISASTER_SUMMARY
# 		WHERE BEGIN_DATE BETWEEN '{}' AND '{}'
# 		AND STATE IN (SELECT UPPER(NAME) FROM STATE)
# 		GROUP BY STATE
# 		ORDER BY 2 DESC
# 		'''.format(start_date, end_date)

# 		conn = e.connect()
# 		query = conn.execute(sql)
# 		json_data = []
# 		for result in query:
# 			d = {
# 				'STATE': result.STATE,
# 				'DAMAGE_PROPERTY': result.DAMAGE_PROPERTY
# 			}
# 			json_data.append(d)
# 		return jsonify(items = json_data)