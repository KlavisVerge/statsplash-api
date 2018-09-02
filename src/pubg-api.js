const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    let promises = [];
    var options = {
        url: 'https://api.pubg.com/shards/' + event.queryStringParameters.region + '/players?filter[playerNames]=' + event.queryStringParameters.playerName,
        headers: {
            'Authorization': 'Bearer ' + process.env.PUBG_API_KEY,
            'Accept': 'application/vnd.api+json'
        }
    };
    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with PUBG API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        const[results] = responses;
        return context.succeed({
            statusCode: 200,
            body: JSON.stringify(results),
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Methods': 'GET',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,XAmz-Security-Token',
                'Access-Control-Allow-Origin': '*'
            }
        });
    }).catch(function(error) {
        return context.succeed({
            statusCode: 200,
            body: 'There was an error processing your request',
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Methods': 'POST',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,XAmz-Security-Token',
                'Access-Control-Allow-Origin': '*'
            }
        });
    });
}