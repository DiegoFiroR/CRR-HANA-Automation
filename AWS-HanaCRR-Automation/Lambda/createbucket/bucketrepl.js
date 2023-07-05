var aws = require('aws-sdk');
var response = require('cfn-response');
exports.handler = function(event, context, callback){

    if (event.RequestType == 'Create' || event.RequestType == 'Update'){
  //  Create Destination S3 Bucket
    var s3 = new aws.S3({region: event.ResourceProperties.DestBucketRegion});
        var bucketParams = {
            Bucket: event.ResourceProperties.DestBucketName,
        };
        s3.createBucket(bucketParams, function(err, data) {
            if (err){
                console.log(err, err.stack);
                response.send(event, context, response.FAILED, err);
            }
            else {
                         console.log(data);           // successful response
                         response.send(event, context, response.SUCCESS, {}, event.destBucketName);
                         callback(null,'Bucket created!'); }
                   });

            }

    else if (event.RequestType == 'Delete'){
        console.log('Please delete the ' + event.PhysicalResourceId + ' bucket.');
        response.send(event, context, response.SUCCESS, {}, event.PhysicalResourceId);
        callback(null);
    }
};
