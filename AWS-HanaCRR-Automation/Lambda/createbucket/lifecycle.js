var aws = require('aws-sdk');
var response = require('cfn-response');
exports.handler = function(event, context, callback){
var s3 = new aws.S3({region: event.ResourceProperties.DestBucketRegion});
    if (event.RequestType == 'Create' || event.RequestType == 'Update'){

    // Put lifecycle configuration for Prefix DAILY and move it GLACIER aftet 10 days and delete after 365
       var s3lifecycle = {
        Bucket: event.ResourceProperties.DestBucketName,
        LifecycleConfiguration: {
         Rules: [
            {
           Expiration: {
            Days: 365
           },
           Filter: {
            Prefix: "DAILY/"
           },
           ID: "DAILY",
           Status: "Enabled",
           Transitions: [
              {
             Days: 10,
             StorageClass: "GLACIER"
            }
           ]
          }
         ]
        }
       };
       s3.putBucketLifecycleConfiguration(s3lifecycle, function(err, data) {
         if (err) console.log(err, err.stack); // an error occurred
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
