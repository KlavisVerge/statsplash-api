const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    let promises = [];

    let options = {
        url: 'https://' + event.queryStringParameters.region.toLowerCase() + '.api.riotgames.com/lol/match/v3/matches/' + event.queryStringParameters.gameId + '?api_key=' + process.env.API_KEY
    };

    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with Riot Games API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        let[results] = responses;
        return context.succeed({
            statusCode: 200,
            body: JSON.stringify(results),
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Methods': 'POST',
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