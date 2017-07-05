function pickDate(divId){
 
    $(function() {
    $( "#" + divId ).datepicker(
        {dateFormat: 'yymmdd',
    	changeYear: true }
        );
    $( "#" + divId ).datepicker("show");
  });
}

/*
	populate the dropdown list with available states
*/
var options ='';
$.getJSON("http://localhost:5000/api/list_states/", 
	function (data){
		
		// console.log(data)
		$.each(data['data'], function(key, val){

			// options += '<option value="' + val.NAME + '" text="' + val.NAME + '" />';
			options += '<option value="' + val.NAME + '">' + val.NAME + ' </option>';
		});
	$('#dropdown_state').append(options);
});


/*
	When the submit button is pressed, Pass the dates to the APIs and fetch the data
	to populate the dashboard
*/
var submit = document.getElementById("send")
submit.addEventListener("click", function test(){

	"user strict"
	var start_date,
		end_date,
		state;


	start_date = document.getElementById("start_date").value;
	end_date = document.getElementById("end_date").value;
	state = document.getElementById("dropdown_state").value;

	// state = state.toUpperCase();

	// console.log(state)


	dailyDamage(start_date, end_date, state);
	injuryDeathPie(start_date, end_date, state);
	mostDamagedStates(start_date, end_date);
	top10Casualties(start_date, end_date);
	top5Events(start_date, end_date, state);
	// injuryDeath(start_date, end_date, state);



	// alert("Start is :" + start_date + " and End date is: " + end_date);
});


/*
	get top 5 most disastrous events for the period
*/
function top5Events(start_date, end_date, state){
	var event_type = [];
	var damage_property = [];
	var damage_crops = [];

	// Use JQuery to get data from api
	$.getJSON("http://localhost:5000/api/events/"  + start_date + "/" + end_date + "/" +state.toUpperCase() , 
        function (data) {
    		// console.log(data)

    		/* 
    			loop through the "data" object and 
    			assign the parts needed to populate the graph 
    		*/
    		var counter = 0
    		$.each( data['data'], function( key, val ) {

    			/* 
    				Loop through the data set and assign each piece of data to a different
    				array
    			*/
				event_type[counter] = String(val.EVENT_TYPE)
				damage_property[counter] = Number(val.DAMAGE_PROPERTY)
				damage_crops[counter] = Number(val.DAMAGE_CROPS)
				counter++
				// console.log(counter)							
			});

			// console.log(data)
			// console.log(event_type)

			Highcharts.chart('myChart', {
			    chart: {
			        type: 'column'
			    },
			    title: {
			    	/* Convert the start and end date to a more human readable format */
			        text: 'Top 5 worst Disasters in ' + state + ' between ' + 
			        new Date(
				        	start_date.substr(0,4) + "/" + 
				        	start_date.substr(4,2) + "/" + 
				        	start_date.substr(6,2)
			        	).toDateString() + 
			        ' and ' + 
			        new Date(
				        	end_date.substr(0,4) + "/" + 
				        	end_date.substr(4,2) + "/" + 
				        	end_date.substr(6,2)
			        	).toDateString()
			    },
			    subtitle: {
			        text: 'Source Data: https://www1.ncdc.noaa.gov/pub/data/swdi/stormevents/csvfiles/'
			    },

			    xAxis: {
			        categories: event_type,
			        crosshair: true
			    },
			    yAxis: {
			        min: 0,
			        title: {
			            text: 'Damage Cost (Millions)'
			        }
			    },
			    tooltip: {
			        headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
			        pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
			            '<td style="padding:0"><b>{point.y:.3f} Million</b></td></tr>',
			        footerFormat: '</table>',
			        shared: true,
			        useHTML: true
			    },
			    plotOptions: {
			        column: {
			            pointPadding: 0.2,
			            borderWidth: 0
			        }
			    },
			    series: [{
			        name: 'Propery Damage',
			        data: damage_property

			    }, {
			        name: 'Crop Damage',
			        data: damage_crops

			    }]
			});
    	});
}


/*

	Shows top 10 most damaged states

*/

function mostDamagedStates(start_date, end_date){

	var states = []
	var damage_property = []
	var damage_crops =[]
	var injury_direct = []
	var injury_indirect = []
	var death_direct = []
	var death_indirect = []

	var counter=0
	$.getJSON("http://localhost:5000/api/summary/" + start_date + "/" + end_date, function (data) {

		$.each(data['data'], function(key, val) {

				states[counter] = val.STATE
				damage_property[counter] = val.DAMAGE_PROPERTY
				damage_crops[counter]= val.DAMAGE_CROPS
				// injury_direct[counter] = val.INJURIES_DIRECT
				// injury_indirect[counter] = val.INJURIES_INDIRECT
				// death_direct[counter] = val.DEATHS_DIRECT
				// death_indirect[counter] = val.DEATHS_INDIRECT

				counter++
		});

		console.log(states)
		console.log(injury_direct)

		Highcharts.chart('disaster_summary', {
		    chart: {
		        type: 'column'
		    },
		    title: {
		        text: 'Top 10 Most Damaged states for the period.'
		    },
		    xAxis: {
		        categories: states
		    },
		    yAxis: [{
		        min: 0,
		        title: {
		            text: 'Damages (millions)'
		        }
		    }/*, {
		        title: {
		            text: 'Injuries/Deaths'
		        },
		        opposite: true
		    }*/],
		    legend: {
		        shadow: false
		    },
		    tooltip: {
		        shared: true
		    },
		    plotOptions: {
		        column: {
		            pointPadding: 0.2,
		            borderWidth: 0
		            // grouping: false,
		            // shadow: false,
		            // borderWidth: 0
		        }
		    },
		    series: [{
		        name: 'Property Damage',
		        // color: 'rgba(165,170,217,1)',
		        data: damage_property,
		        tooltip: {
		            valuePrefix: '$',
		            valueSuffix: ' M'
		        },
		        pointPadding: 0.3,
		        pointPlacement: -0.2
		    }, {
		        name: 'Crop Damage',
		        // color: 'rgba(126,86,134,.9)',
		        data: damage_crops,
		        tooltip: {
		            valuePrefix: '$',
		            valueSuffix: ' M'
		        },
		        pointPadding: 0.4,
		        pointPlacement: -0.2
		    }/*, {
		        name: 'Direct Injuries',
		        // color: 'rgba(248,161,63,1)',
		        data: injury_direct,
		        pointPadding: 0.3,
		        pointPlacement: 0.2,
		        yAxis: 1
		    }, {
		        name: 'Indirect Injuries',
		        // color: 'rgba(186,60,61,.9)',
		        data: injury_indirect,
		        pointPadding: 0.4,
		        pointPlacement: 0.2,
		        yAxis: 1
		    }, {
		        name: 'Indirect Deaths',
		        // color: 'rgba(186,60,61,.9)',
		        data: death_indirect,
		        pointPadding: 0.3,
		        pointPlacement: 0.2,
		        yAxis: 1
		    }, {
		        name: 'Direct Deaths',
		        // color: 'rgba(186,60,61,.9)',
		        data: death_direct,
		        pointPadding: 0.4,
		        pointPlacement: 0.2,
		        yAxis: 1
		    }*/]
		});


	});
}



/*

	Shows top 10 most damaged states

*/

function top10Casualties(start_date, end_date){

	var states = []
	var damage_property = []
	var damage_crops =[]
	var injury_direct = []
	var injury_indirect = []
	var death_direct = []
	var death_indirect = []

	var counter=0
	$.getJSON("http://localhost:5000/api/top_casualties/" + start_date + "/" + end_date, function (data) {

		$.each(data['data'], function(key, val) {

				states[counter] = val.STATE
				// damage_property[counter] = val.DAMAGE_PROPERTY
				// damage_crops[counter]= val.DAMAGE_CROPS
				injury_direct[counter] = val.INJURIES_DIRECT
				injury_indirect[counter] = val.INJURIES_INDIRECT
				death_direct[counter] = val.DEATHS_DIRECT
				death_indirect[counter] = val.DEATHS_INDIRECT

				counter++
		});

		console.log(states)
		console.log(injury_direct)

		Highcharts.chart('top10_injury_death', {
		    chart: {
		        type: 'column'
		    },
		    title: {
		        text: 'Top 10 States with the most casualties.'
		    },
		    xAxis: {
		        categories: states
		    },
		    yAxis: [{
		        min: 0,
		        title: {
		            text: 'Injuries/Deaths'
		        }
		    }],
		    legend: {
		        shadow: false
		    },
		    tooltip: {
		        shared: true
		    },
		    plotOptions: {
		        column: {
		            pointPadding: 0.2,
		            borderWidth: 0
		            // grouping: false,
		            // shadow: false,
		            // borderWidth: 0
		        }
		    },
		    series: [{
		        name: 'Direct Deaths',
		        // color: 'rgba(165,170,217,1)',
		        data: death_direct,
		        pointPadding: 0.4,
		        pointPlacement: -0.2
		    }, {
		        name: 'Indirect Deaths',
		        // color: 'rgba(248,161,63,1)',
		        data: death_indirect,
		        pointPadding: 0.3,
		        pointPlacement: 0.2,
		    }, {
		        name: 'Direct Injuries',
		        // color: 'rgba(186,60,61,.9)',
		        data: injury_direct,
		        pointPadding: 0.4,
		        pointPlacement: 0.2,
		    }, {
		        name: 'Indirect Injuries',
		        // color: 'rgba(186,60,61,.9)',
		        data: injury_indirect,
		        pointPadding: 0.3,
		        pointPlacement: 0.2,
		    }]
		});


	});
}

/*
	Plots injuries and deaths on a pie chart
*/
function injuryDeathPie(start_date, end_date, state){

	$.getJSON("http://localhost:5000/api/injury_death/" + start_date + "/" + end_date + "/" + state.toUpperCase(), 
		function (data) {

			injury_direct = data['data'][0].INJURIES_DIRECT
			injury_indirect = data['data'][0].INJURIES_INDIRECT

			death_direct = data['data'][0].DEATHS_DIRECT
			death_indirect = data['data'][0].DEATHS_INDIRECT

			console.log(injury_direct)

			Highcharts.chart('injury_death_pie', {
			    title: {
			        text: 'Death and Injury count for the period.'
			    },
			    series: [{
			        type: 'pie',
			        name: 'Total: ',
			        data: [{
			            name: 'Direct Injuries',
			            y: injury_direct,
			            color: Highcharts.getOptions().colors[0] // Jane's color
			        }, {
			            name: 'Indirect Injuries',
			            y: injury_indirect,
			            color: Highcharts.getOptions().colors[1] // John's color
			        }, {
			            name: 'Direct Deaths',
			            y: death_direct,
			            color: Highcharts.getOptions().colors[2] // Joe's color
			        }, {
			            name: 'Indirect Deaths',
			            y: death_indirect,
			            color: Highcharts.getOptions().colors[3] // Joe's color
			        }],
			        showInLegend: false,
			        dataLabels: {
			            enabled: true
			        }
			    }]
			});

	})

}

/*
	Plots injuries and deaths on a line chart
*/
function injuryDeath(start_date, end_date, state){

	var num_days=[]
	
	var injury_direct = []
	var injury_indirect = []

	var death_direct = []
	var death_indirect = []

	$.getJSON("http://localhost:5000/api/injury_death/" + start_date + "/" + end_date + "/" + state.toUpperCase(), 
		function (data) {

			// console.log(data)
			var counter = 0;
			$.each( data['data'], function(key, val) {

				num_days[counter] = 
        		Date.UTC(
				        	Number(val.BEGIN_DATE.substr(0,4)),
				        	Number(val.BEGIN_DATE.substr(4,2)),
				        	Number(val.BEGIN_DATE.substr(6,2))
				    )

        		injury_direct[counter] = new Array()
        		injury_indirect[counter] = new Array()
        		
        		death_direct[counter] = new Array()
        		death_indirect[counter] = new Array()

        		injury_direct[counter][0] = num_days[counter]
				injury_direct[counter][1] = val.INJURIES_DIRECT

				injury_indirect[counter][0] = num_days[counter]
				injury_indirect[counter][1] = val.INJURIES_DIRECT

				death_direct[counter][0] = num_days[counter]
				death_direct[counter][1] = val.DEATHS_DIRECT

				death_indirect[counter][0] = num_days[counter]
				death_indirect[counter][1] = val.DEATHS_INDIRECT

				counter++
			});

			console.log(death_direct)
			Highcharts.chart('injury_death', {
			    chart: {
			        type: 'spline'
			    },
			    title: {
			        text: 'Snow depth at Vikjafjellet, Norway'
			    },
			    subtitle: {
			        text: 'Irregular time data in Highcharts JS'
			    },
			    xAxis: {
			        type: 'datetime',
			        dateTimeLabelFormats: { // don't display the dummy year
			            month: '%e. %b',
			            year: '%b'
			        },
			        title: {
			            text: 'Date'
			        }
			    },
			    yAxis: {
			        title: {
			            text: 'Snow depth (m)'
			        },
			        min: 0
			    },
			    tooltip: {
			        headerFormat: '<b>{series.name}</b><br>',
			        pointFormat: '{point.x:%e. %b}: {point.y:.2f} m'
			    },

			    plotOptions: {
			        spline: {
			            marker: {
			                enabled: true
			            }
			        }
			    },

			    series: [{
			        name: 'Injuries Direct',
			        // Define the data points. All series have a dummy year
			        // of 1970/71 in order to be compared on the same x axis. Note
			        // that in JavaScript, months start at 0 for January, 1 for February etc.
			        data: injury_direct
			    }, {
			        name: 'Injuries Indirect',
			        data: injury_indirect
			    }, {
			        name: 'Deaths Direct',
			        data: death_direct
			    }, {
			        name: 'Deaths Indirect',
			        data: death_indirect
			    }]
			});



		}
	);

}



/*
	Populates the property and crop damage charts

*/

function dailyDamage(start_date, end_date, state){

	var num_days = []
	var damage_property = []
	var	damage_crops = []
	var property_data = []
	var crop_data = []

	$.getJSON("http://localhost:5000/api/daily_damage/" + start_date + "/" + end_date + "/" + state.toUpperCase(), 
        function (data) {

        	var counter = 0
        	$.each( data['data'], function(key, value) {

        		// num_days[counter] = value.BEGIN_DATE
        		num_days[counter] = 
        		Date.UTC(
				        	Number(value.BEGIN_DATE.substr(0,4)),
				        	Number(value.BEGIN_DATE.substr(4,2)),
				        	Number(value.BEGIN_DATE.substr(6,2))
				    )
        		damage_property[counter] = value.DAMAGE_PROPERTY
        		damage_crops[counter] = value.DAMAGE_CROPS
        		
        		property_data[counter] = new Array()
        		property_data[counter][0]=num_days[counter]
        		property_data[counter][1]=damage_property[counter]

        		crop_data[counter] = new Array()
        		crop_data[counter][0] = num_days[counter]
        		crop_data[counter][1] = damage_crops[counter]

        		counter++
        	});

        	// console.log(property_data)

        	Highcharts.chart('daily_property_damage', {
			    chart: {
			        zoomType: 'x'
			    },
			    title: {
			        text: 'Property Damage for the period'
			    },
			    subtitle: {
			        text: document.ontouchstart === undefined ?
			                'Click and drag in the plot area to zoom in' : 'Pinch the chart to zoom in'
			    },
			    xAxis: {
			        type: 'datetime',
			        dateTimeLabelFormats: { // don't display the dummy year
		            	month: '%e. %b',
		            	year: '%b'
		        	}
			        // categories: num_days,
			        // pointInterval: 3600 * 1000 *24 * 30// 30 days
			        // pointIntervalUnit: 'months'
			    },
			    yAxis: {
			        title: {
			            text: 'Damage Cost (Millions)'
			        }
			    },
			    legend: {
			        enabled: false
			    },
			    plotOptions: {
			        area: {
			            fillColor: {
			                linearGradient: {
			                    x1: 0,
			                    y1: 0,
			                    x2: 0,
			                    y2: 1
			                },
			                stops: [
			                    [0, Highcharts.getOptions().colors[0]],
			                    [1, Highcharts.Color(Highcharts.getOptions().colors[0]).setOpacity(0).get('rgba')]
			                ]
			            },
			            marker: {
			                radius: 2
			            },
			            lineWidth: 1,
			            states: {
			                hover: {
			                    lineWidth: 1
			                }
			            },
			            threshold: null
			        }
			    },

			    series: [{
			        type: 'area',
			        name: 'Cost: ',
			        data:property_data
			    }]
			});



        	Highcharts.chart('daily_crop_damage', {
			    chart: {
			        zoomType: 'x'
			    },
			    title: {
			        text: 'Crop Damage for the period'
			    },
			    subtitle: {
			        text: document.ontouchstart === undefined ?
			                'Click and drag in the plot area to zoom in' : 'Pinch the chart to zoom in'
			    },
			    xAxis: {
			        type: 'datetime',
			        dateTimeLabelFormats: { // don't display the dummy year
		            	month: '%e. %b',
		            	year: '%b'
		        	}
			        // categories: num_days,
			        // pointInterval: 3600 * 1000 *24 * 30// 30 days
			        // pointIntervalUnit: 'months'
			    },
			    yAxis: {
			        title: {
			            text: 'Damage Cost (Millions)'
			        }
			    },
			    legend: {
			        enabled: false
			    },
			    plotOptions: {
			        area: {
			            fillColor: {
			                linearGradient: {
			                    x1: 0,
			                    y1: 0,
			                    x2: 0,
			                    y2: 1
			                },
			                stops: [
			                    [0, Highcharts.getOptions().colors[1]],
			                    [1, Highcharts.Color(Highcharts.getOptions().colors[1]).setOpacity(0).get('rgba')]
			                ]
			            },
			            marker: {
			                radius: 2
			            },
			            lineWidth: 1,
			            states: {
			                hover: {
			                    lineWidth: 1
			                }
			            },
			            threshold: null
			        }
			    },

			    series: [{
			        type: 'area',
			        name: 'Cost: ',
			        data:crop_data
			    }]
			});



			/*
			Highcharts.chart('daily_damage', {

			    title: {
			        text: 'Daily Damage Cost'
			    },

			    subtitle: {
			        text: 'Source: thesolarfoundation.com'
			    },

			    yAxis: {
			        title: {
			            text: 'Damage (Millions)'
			        }
			    },
			    xAxis: {
			    	type: 'datetime',
			    	dateTimeLabelFormats: { // don't display the dummy year
	            		month: '%e. %b',
	            		year: '%b'
	        		},
			    	categories: num_days
			    },
			    legend: {
			        layout: 'vertical',
			        align: 'right',
			        verticalAlign: 'middle'
			    },
			    series: [{
			        name: 'Property Damage',
			        data: damage_property
			    }, {
			        name: 'Crop Damage',
			        data: damage_crops
			    }]

			});
			*/

        });


}