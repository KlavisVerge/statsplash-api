const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    let promises = [];
    let requestParams = "";
    let split = event.queryStringParameters.games.split('|');
    for(var i = 0; i < split.length; i++){
        if(i == 0){
            requestParams += 'name=' + split[i];
        }else{
            requestParams += '&name=' + split[i];
        }
    }
    var options = {
        url: 'https://api.twitch.tv/helix/games?' + requestParams,
        headers: {
            'Client-ID': process.env.CLIENT_ID
        }
    };
    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with Twitch API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        const[resultsOuter] = responses;
        let parsed = JSON.parse(resultsOuter);
        const retObj = {
            "game": parsed
        };
        return context.succeed({
            statusCode: 200,
            body: JSON.stringify(retObj),
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
};