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
        console.log('error1: ' + JSON.stringify(err));
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with Twitch API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        const[resultsOuter] = responses;
        let parsed = JSON.parse(resultsOuter);
        let promises = [];
        // url: 'https://api.twitch.tv/kraken/streams/?game=' + event.queryStringParameters.gameName,
        var liveStreams = {
            url: 'https://api.twitch.tv/helix/streams?game_id=' + JSON.stringify(parsed.data[0].id).replace(/\"/g, "").replace(/\\/g, ""),
            headers: {
                'Client-ID': process.env.CLIENT_ID
            }
        };
        // console.log('firing request: ' + JSON.stringify(liveStreams));
    
        promises.push(request(liveStreams).promise().then((resInner) => {
            return resInner;
        }).catch(function (err) {
            console.log('error2: ' + JSON.stringify(err));
            return Promise.reject({
                statusCode: err.statusCode,
                message: 'Error interacting with Twitch API.'
            });
        }));
        return Promise.all(promises).then((responses) => {
            const[streams] = responses;
            let streamArray = [];
            let parsedStreams = JSON.parse(streams);
            for(let i = 0; i < parsedStreams.data.length; i++){
                // console.log('1: ' + parsedStreams.data[i].user_name);
                // console.log('2: ' + parsedStreams.data[i].title);
                // console.log('3: ' + parsedStreams.data[i].thumbnail_url);
                // console.log('4: ' + parsedStreams.data[i].viewer_count);
                streamArray.push({
                   'channel':{
                       'url': 'https://www.twitch.tv/' + parsedStreams.data[i].user_name,
                       'display_name': parsedStreams.data[i].user_name,
                       'status': parsedStreams.data[i].title
                   },
                   'preview':{
                       'medium': parsedStreams.data[i].thumbnail_url.replace('{width}', '350').replace('{height}', '210')
                   },
                   'viewers': parsedStreams.data[i].viewer_count
                });
            }
            let streamsObj = {
              'streams': streamArray  
            };
            const retObj = {
                "game": parsed,
                "liveStreams": JSON.stringify(streamsObj)
            };
            //<a href=[[item.channel.url]] target="_blank"><twitch-stream streamer=[[item.channel.display_name]] thumbnailurl=[[item.preview.medium]] 
            //title=[[item.channel.status]] viewercount=[[item.viewers]]></twitch-stream></a>
            
            //"streams": "{\"data\":[{\"id\":\"35789006256\",\"user_id\":\"29289159\",\"user_name\":\"hashinshin\",\"game_id\":\"21779\",\"type\":\"live\",\"title\":\"GRANDMASTER GODZILLA TOP!\"
            //,\"viewer_count\":6063,\"started_at\":\"2019-09-26T22:09:42Z\",\"language\":\"en\",
            //\"thumbnail_url\":\"https://static-cdn.jtvnw.net/previews-ttv/live_user_hashinshin-{width}x{height}.jpg\",
            //\"tag_ids\":[\"e1a43486-eee5-4f36-9ee6-76e72af00180\",\"1eba3cfe-51cc-460a-8259-bc8bb987f904\",\"24701825-fce2-4fec-b3f6-a963950febe0\",\"6ea6bca4-4712-4ab9-a906-e3336a9d8039\"]},
            //{\"id\":\"35790226976\",\"user_id\":\"25080754\",\"user_name\":\"Pobelter\",\"game_id\":\"21779\",\"type\":\"live\",
            
            
            // console.log('final response: ' + JSON.stringify(retObj));
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
        }).catch(function (err) {
            console.log('error2: ' + JSON.stringify(err));
            return Promise.reject({
                statusCode: err.statusCode,
                message: 'Error interacting with Twitch API.'
            });
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