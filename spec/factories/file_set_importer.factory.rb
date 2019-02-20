FactoryBot.define do
  factory :file_set_importer, class: FileSetImporter do
    skip_create
    metadata {
      {
          "id" => "n583xw08g",
          "label" => "b10371138_367.tif",
          "import_url" => "https://scih-uploads.s3.amazonaws.com/b10371138/b10371138_367.tif?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJ626AGZAL6CGGELQ%2F20181129%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20181129T132242Z&X-Amz-Expires=14400&X-Amz-SignedHeaders=host&X-Amz-Signature=979b4fce1cb0faf474582973ae513c461229cc9eaab55e8a4454487599f858c6",
          "creator" => [
              "njoniec@sciencehistory.org"
          ],
          "depositor" => "njoniec@sciencehistory.org",
          "title" => [
              "b10371138_367.tif"
          ],
          "date_uploaded" => "2018-11-29T14:09:26+00:00",
          "date_modified" => "2018-11-29T14:09:26+00:00",
          "access_control_id" => "4d4c2f66-78a3-4385-a835-765064056526",
          "file_url" => "http://172.31.59.63:8080/fedora/rest/prod/n5/83/xw/08/n583xw08g/files/5ba58f0d-e528-4841-bd0f-e73e832b5596",
          "sha_1" => "1fac2923901895582e0406bfa40779a662d1010e"
      }
    }
    path {
      "/path/to/scihist_digicoll/tmp/import/filesets/8049g504g.json"
    }
  end
end
