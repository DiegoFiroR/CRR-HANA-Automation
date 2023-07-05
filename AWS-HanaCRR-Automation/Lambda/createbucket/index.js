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
          console.log(data.KeyMetadata.KeyId);
          var kmsaliasparams = {
            AliasName: "alias/"+ event.ResourceProperties.DestKmsId +"",
            TargetKeyId: data.KeyMetadata.KeyId
          };
          kms.createAlias(kmsaliasparams, function(err, data) {
          if (err) console.log(err, err.stack); // an error occurred
          else     console.log(data);           // successful response
        });
        }
    });
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
                console.log(data);
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
                        console.log(data);

                    }
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
                else     console.log(data);           // successful response
              });
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
                  }
                });
                // Put lifecycle configuration for Prefix DAILY and move it GLACIER aftet 10 days and delete after 365
                  console.log('s3lifecycle Now');
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

            });
        }
    });
  }
    else if (event.RequestType == 'Delete'){
        console.log('Please delete the ' + event.PhysicalResourceId + ' bucket.');
        response.send(event, context, response.SUCCESS, {}, event.PhysicalResourceId);
        callback(null);
    }
};
