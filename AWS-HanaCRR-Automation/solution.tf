

/* 1.	Create Lambda execution role
2.	Create and trigger Lambda functions to launch destination resources in other region
3.	Create destination CMK key and create Alias. . Allow only EC2 role to encypt and decrypt and admin role to maintain the key. 
4.	Create and trigger Lambda functions to create and configure destination bucket 
a.	Create destination bucket 
b.	Update bucket properties to enable bucket versioning
c.	 Update bucket properties to default encryption using aws:kms and created CMK
d.	Update bucket policy to deny upload objects which are not encrypted
e.	Update bucket lifecycle to move objects from standard s3 to glacier. Rotation period 7 days in stander s3 and one year in glacier before delete them from glacier. 
5.	Create source CMK key and create Alias in current region. Allow only EC2 role to encypt and decrypt and admin role to maintain the key. 
6.	Create s3 service role to allow s3 replication. Create custom policy to allow only replication objects which are encrypt using source CMK and encrypt them back using target CMK key. 
7.	Create and configure source bucket
a.	Update bucket properties to enable bucket versioning
b.	Update bucket properties to default encryption using aws:kms and created CMK
c.	Update bucket policy to deny upload objects which are not encrypted
d.	Update bucket properties to default encryption using aws:kms and created CMK
e.	Update bucket policy to deny upload objects which are not encrypted
f.	Update bucket lifecycle to move objects from standard s3 to glacier. Rotation period 7 days in stander s3 and one year in glacier before delete
8.	Enable bucket replication.  */

