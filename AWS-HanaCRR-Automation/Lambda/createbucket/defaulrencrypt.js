var aws = require('aws-sdk');
var response = require('cfn-response');
exports.handler = function(event, context, callback){
var s3 = new aws.S3({region: event.ResourceProperties.DestBucketRegion});
    if (event.RequestType == 'Create' || event.RequestType == 'Update'){
      // Use KMS encryption aws:kmsPolicy
      var s3ecryptparams = {
        Bucket: event.ResourceProperties.DestBucketName,
        ServerSideEncryptionConfiguration: {
          Rules: [
            {
              ApplyServerSideEncryptionByDefault: {
                SSEAlgorithm: "aws:kms",
                KMSMasterKeyID: event.ResourceProperties.DestKmsId
              }
            },

          ]
        },
      };
      s3.putBucketEncryption(s3ecryptparams, function(err, data) {
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
