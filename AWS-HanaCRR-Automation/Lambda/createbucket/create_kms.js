var aws = require('aws-sdk');
var response = require('cfn-response');
exports.handler = function(event, context, callback){
  // Create KMS Key to be used for Backup buckets
    var kms = new aws.KMS({region: event.ResourceProperties.DestBucketRegion});
    var kmsPolicy = {
        "Id": "KMS-key-Policy",
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "Enable IAM User Permissions",
                "Effect": "Allow",
                "Principal": {
                     "AWS": "arn:aws:iam::"+ event.ResourceProperties.AccountId +":root"
                 },
                "Action": "kms:*",
                "Resource": "*"
            },
            {
                "Sid": "Allow access for Key Administrators",
                "Effect": "Allow",
                "Principal": {
                    "AWS": ""+ event.ResourceProperties.KmsAdminRole +"",
                },
                "Action": [
                    "kms:Create*",
                    "kms:Describe*",
                    "kms:Enable*",
                    "kms:List*",
                    "kms:Put*",
                    "kms:Update*",
                    "kms:Revoke*",
                    "kms:Disable*",
                    "kms:Get*",
                    "kms:Delete*",
                    "kms:TagResource",
                    "kms:UntagResource",
                    "kms:ScheduleKeyDeletion",
                    "kms:CancelKeyDeletion"
                ],
                "Resource": "*"
           },
           {
                "Sid": "Allow use of the key",
                "Effect": "Allow",
                "Principal": {
                        "AWS": ""+ event.ResourceProperties.KMSEC2Role +""
                    },
                "Action": [
                        "kms:Encrypt",
                        "kms:Decrypt",
                        "kms:ReEncrypt*",
                        "kms:GenerateDataKey*",
                        "kms:DescribeKey"

                    ],
                "Resource": "*"
            }
        ]
    };
    if (event.RequestType == 'Create' || event.RequestType == 'Update'){
    var CMKKey = {
      Description: 'KMS Key to Encrypt Backup S3 Bucket',
      KeyUsage: 'ENCRYPT_DECRYPT',
      Origin: 'AWS_KMS' ,
      Policy: JSON.stringify(kmsPolicy),
      Tags: [
        {
          TagKey: 'Name',
          TagValue: 'KMS Key For Destination S3 Backup'
        },
      ]
    };
    kms.createKey(CMKKey, function(err, data) {
      if (err) { console.log(err, err.stack); }// an error occurred
      else  {
          console.log(data);           // successful response
          console.log(data.KeyMetadata.Arn);
          var kmsarnid = data.KeyMetadata.Arn
          var kmsaliasparams = {
            AliasName: "alias/"+ event.ResourceProperties.DestKmsId +"",
            TargetKeyId: data.KeyMetadata.KeyId
          };
          kms.createAlias(kmsaliasparams, function(err, data) {
          if (err) console.log(err, err.stack); // an error occurred
          else {
            console.log(data);           // successful response
            console.log(kmsarnid);
            response.send(event, context, response.SUCCESS, {'Message': kmsarnid}, event.DestKmsId);
            callback(null,'KMS key created!'); }
        });
        }
    });
     }
    else if (event.RequestType == 'Delete'){
        console.log('Please delete the ' + event.PhysicalResourceId + ' KMS.');
        response.send(event, context, response.SUCCESS, {}, event.PhysicalResourceId);
        callback(null);
    }

};
