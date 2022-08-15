function transformCSVtoJSON(line) {
    var values = line.split(',');
    var properties = [
      'location',
      'average_temperature',
      'month',
      'inches_of_rain',
      'is_current',
      'latest_measurement',
    ];
    var weatherInCity = {};
  
    for (var count = 0; count < values.length; count++) {
      if (values[count] !== 'null') {
        weatherInCity[properties[count]] = values[count];
      }
    }
  
    var jsonString = JSON.stringify(weatherInCity);
    return jsonString;
  }