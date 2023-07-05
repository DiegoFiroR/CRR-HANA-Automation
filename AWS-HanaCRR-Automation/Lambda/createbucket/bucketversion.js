var aws = require('aws-sdk');
var response = require('cfn-response');
exports.handler = function(event, context, callback){
var s3 = new aws.S3({region: event.ResourceProperties.DestBucketRegion});
    if (event.RequestType == 'Create' || event.RequestType == 'Update'){

        var versioningParams = {
            Bucket: event.ResourceProperties.DestBucketName,
            VersioningConfiguration: {
                Status: 'Enabled'
            }
        };
        // Enable bucket Versioning
        s3.putBucketVersioning(versioningParams, function(err, data) {
            if (err) {
                console.log(err, err.stack);
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
