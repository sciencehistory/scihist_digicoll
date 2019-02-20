FactoryBot.define do
  factory :collection_importer, class: CollectionImporter do
    skip_create
    metadata {
      {
          "id" => "mg74qm28w",
          "depositor" => "clu@sciencehistory.org",
          "title" => [
              "Phil Allegretti Pesticide Collection"
          ],
          "description" => [
              "This collection consists of 3D objects, including cans, sprayers, and diffusers, as well as ephemera related to DDT pesticide and insecticide in the U.S. in the mid-20th century."
          ],
          "representative_image_path" => "mg74qm28w_2x.jpg",
          "access_control_id" => "0a344e7b-4b7d-42b6-bbd5-84aa5e38b5e3",
          "members" => [
              # "9593tv75c",
              # "hm50ts404",
              # "5712m741t",
              # "9s161700f",
              # "6395w7883",
              # "6969z166t",
              # "2z10wr14g"
          ]
      }
    }
    path {
      "/path/to/scihist_digicoll/tmp/import/collections/mg74qm28w.json"
    }
  end
end
