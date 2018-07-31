const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    let promises = [];
    var options = {
        url: 'https://api.fortnitetracker.com/v1/profile/' + event.queryStringParameters.platform + '/' + event.queryStringParameters.epicNickname,
        headers: {
            'TRN-Api-Key': process.env.FORTNITE_TRN_API_KEY
        }
    };
    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with Fortnite API.'
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
    });
}