import os
import boto3
from botocore.client import Config
from fastapi import UploadFile
from typing import Optional
import uuid


class StorageService:
    def __init__(self):
        self.bucket = os.getenv("S3_BUCKET_NAME")
        self.region = os.getenv("AWS_REGION", "us-east-1")

        self.use_s3 = bool(
            os.getenv("AWS_ACCESS_KEY_ID") and os.getenv("AWS_SECRET_ACCESS_KEY") and self.bucket
        )

        if self.use_s3:
            self.s3 = boto3.client(
                's3',
                region_name=self.region,
                config=Config(s3={'addressing_style': 'virtual'})
            )
        else:
            os.makedirs("./.local_uploads", exist_ok=True)

    async def upload_file(self, file: UploadFile, key: Optional[str] = None) -> Optional[str]:
        key = key or f"uploads/{uuid.uuid4()}-{file.filename or 'image.jpg'}"

        if self.use_s3:

            body = await file.read()
            self.s3.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=body,
                ContentType=file.content_type or 'application/octet-stream',
                ACL='public-read'
            )
            return f"https://{self.bucket}.s3.{self.region}.amazonaws.com/{key}"
        else:

            path = os.path.join("./.local_uploads", key.replace("/", "_"))
            content = await file.read()
            with open(path, 'wb') as f:
                f.write(content)
            return f"/static/{os.path.basename(path)}"


