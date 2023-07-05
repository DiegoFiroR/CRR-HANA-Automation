var aws = require('aws-sdk');
var response = require('cfn-response');
exports.handler = function(event, context, callback){
var s3 = new aws.S3({region: event.ResourceProperties.DestBucketRegion});
    if (event.RequestType == 'Create' || event.RequestType == 'Update'){

    // Deny Uplpad non ecvrypt object
    var s3AclPolicy = {
           "Version": "2012-10-17",
           "Id": "PutObjPolicy",
           "Statement": [
               {
                    "Sid": "DenyIncorrectEncryptionHeader",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "s3:PutObject",
                    "Resource": "arn:aws:s3:::"+ event.ResourceProperties.DestBucketName +"/*",
                    "Condition": {
                        "StringNotEquals": {
                              "s3:x-amz-server-side-encryption": "aws:kms"
                                 }
                       }
               },
               {
                    "Sid": "DenyUnEncryptedObjectUploads",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "s3:PutObject",
                     "Resource": "arn:aws:s3:::"+ event.ResourceProperties.DestBucketName +"/*",
                    "Condition": {
                        "Null": {
                              "s3:x-amz-server-side-encryption": true
                                }
                        }
               }
        ]
    };
    console.log('s3AclPolicy Now');
    var DenyUploadNonEncryptObjectParams = {
     Bucket: event.ResourceProperties.DestBucketName,
     Policy: JSON.stringify(s3AclPolicy),
    };
    s3.putBucketPolicy(DenyUploadNonEncryptObjectParams, function(err, data) {
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
