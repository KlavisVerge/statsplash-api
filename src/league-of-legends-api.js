const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    let promises = [];
    let options = {
        url: 'https://na1.api.riotgames.com/lol/summoner/v4/summoners/by-name/' + event.queryStringParameters.summonerName + '?api_key=' + process.env.API_KEY // this gives summoner level basically and accountId, id is summoner id
    };
    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return undefined;
    }));

    let otherRegions = event.queryStringParameters.region;
    if('na' === otherRegions){
        otherRegions = 'na1';
    }

    options = {
        url: 'https://' + otherRegions + '.api.riotgames.com/lol/summoner/v4/summoners/by-name/' + event.queryStringParameters.summonerName + '?api_key=' + process.env.API_KEY // this gives summoner level basically and accountId, id is summoner id
    };
    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return undefined;
    }));

    options = {
        url: 'https://ddragon.leagueoflegends.com/realms/na.json'
    };

    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with DDragon API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        const [na1, rest, realms] = responses;

        let region = '';
        let results = '';
        if(event.queryStringParameters.region === 'na'){
            region = 'na1';
            if(na1 !== undefined){
                results = JSON.parse(na1);
            }
        } else {
            region = event.queryStringParameters.region;
            if(rest !== undefined){
                results = JSON.parse(rest);
            }
        }
        if(results === ''){
            let errObject = {message: 'Player not found in region: ' + event.queryStringParameters.region};
            return context.succeed({
                statusCode: 200,
                body: JSON.stringify(errObject),
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Methods': 'POST',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,XAmz-Security-Token',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
        let promises = [];
        let options = {
            url: 'https://' + region + '.api.riotgames.com/lol/match/v4/matchlists/by-account/' + results.accountId + '?api_key=' + process.env.API_KEY
        };
        promises.push(request(options).promise().then((res) => {
            return res;
        }).catch(function (err) {
            return Promise.reject({
                statusCode: err.statusCode,
                message: 'Error interacting with Riot Games API.'
            });
        }));

        options = {
            url: 'https://' + region + '.api.riotgames.com/lol/league/v4/entries/by-summoner/' + results.id + '?api_key=' + process.env.API_KEY
        };
        promises.push(request(options).promise().then((res) => {
            return res;
        }).catch(function (err) {
            return Promise.reject({
                statusCode: err.statusCode,
                message: 'Error interacting with Riot Games API.'
            });
        }));

        options = {
            url: 'http://ddragon.leagueoflegends.com/cdn/' + JSON.parse(realms).n.summoner + '/data/en_US/champion.json'
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
            console.log('last promise: ' + JSON.stringify(responses));
            let[matchList, positions, allChampions] = responses;
            let matchesProcessed = JSON.parse(matchList);
            allChampions = JSON.parse(allChampions);
            let names = Object.getOwnPropertyNames(allChampions.data);
            let championMap = new Map();
            for(var i = 0; i < names.length; i++) {
                championMap.set(Number(allChampions.data[names[i]].key), allChampions.data[names[i]].name);
            }
            for(var j = 0; j < matchesProcessed.matches.length; j++){
                matchesProcessed.matches[j].championName = championMap.get(matchesProcessed.matches[j].champion);
            }
            let returnObject = {};
            returnObject.account = results;
            returnObject.matchList = matchesProcessed;
            returnObject.positions = positions;
            return context.succeed({
                statusCode: 200,
                body: JSON.stringify(returnObject),
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
    }).catch(function(error) {
        console.log('error: ' + JSON.stringify(error));
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