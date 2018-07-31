const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    let promises = [];
    var options = {
        url: 'https://api.twitch.tv/helix/games?name=' + event.queryStringParameters.gameName,
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

    var liveStreams = {
        url: 'https://api.twitch.tv/kraken/streams/?game=' + event.queryStringParameters.gameName,
        headers: {
            'Client-ID': process.env.CLIENT_ID
        }
    }

    promises.push(request(liveStreams).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with Twitch API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        const[resultsOuter, liveStreams] = responses;
        let parsed = JSON.parse(resultsOuter);
        const retObj = {
            "game": parsed,
            "liveStreams": liveStreams
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
    });
};