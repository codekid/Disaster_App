# Disaster_App

The Disaster_App is a web that imports all the data from [NCDC webbsite](https://www1.ncdc.noaa.gov/pub/data/swdi/stormevents/csvfiles/), stores the information and uses the data to create a dashboard of the number incidents, injuries and deaths for each state.

Dependencies
* Python 3
* Flask
* SQLAlchemy
* Mysqlclient

```
	pip install flask
    pip install sqlalchemy
    pip install mysql-connector-python-rf
```

You can also replicate the environment I had by installing using the requirements.txt file
	
    pip install -r requirements.txt

A version of bootstrap is already in the scripts folder. You'll need to run the table_creation.sql file in order to create the tables that will be needed in your MySQL database. After this is done you 'll need to edit the credentials for your database in the disaster_app.py and disaster_planning.py files

After the tables have been setup and database credentials edited you can now run the disaster_app.py

	python disaster_app.py

### Importing data
'disaster_planning.py' imports all the data into the database and does all the ETL.

Dependencies
* urllib
* BeautifulSoup

```
	pip install urllib
    pip install BeautifulSoup
```

To import the data all just run the script.

	python disaster_planning.py
    
### Access Application

Afer the app has been setup in your local environment Open a Browser of your choosing and navigate to http://localhost:5000/

