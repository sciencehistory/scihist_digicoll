namespace :scihist do
  namespace :data_fixes do
    desc """
    
    Turn off OCR for some 'incorrigible' assets that are causing
    problems with derivative creation,
    per https://github.com/sciencehistory/scihist_digicoll/issues/2306#issuecomment-1671923288.
    
    # bundle exec rake scihist:data_fixes:turn_off_problematic_ocr_assets
    
    """
    task :turn_off_problematic_ocr_assets => :environment do
      incorrigibles = [
        '7235b719-8cc5-4274-9722-e97d1cf3fcf2',
        'e72c3d4d-a39c-4607-8edd-c6449f0dee5c',
        '1f799a99-9c1b-43f7-a1b8-2e08e5a6ab0b',
        'ecb44240-5cd0-4ae5-b22e-7875e0eebb14',
        '550a5553-e769-4bcd-b8cf-b97b9ccc4eec',
        '8d730e3c-f05f-4b31-ba00-7854ee57dbba',
        'dde5bb22-c2c9-48d5-b90a-3882832fa8be',
        'd867f7df-6ca0-4883-9460-19780a92a49e',
        '311045de-c719-4073-810d-d99fe55389dc',
        '02a6a7bf-0a58-46af-8efd-3ca738cd1a9e',
        'da61247a-2da6-460b-b545-38f7877d3d57',
        'd8cb3295-72e1-4f89-8b41-bd6de9ef1ff3',
        '12ca919f-2cdd-4f13-a2f9-07ce39dc3223',
        'feb68068-c01c-4df0-a915-0223291f03bf',
        'cf452424-8763-4489-9ca5-df49d05019d0',
        'd81b2eb0-513f-4933-8a84-2ff8a6873d11',
        '3dc417ba-6dec-4a16-a976-aa796edfef17',
        'cdb1a2d4-b602-4d1b-b723-90a0d5820643',
        '78515fcb-7f6e-4416-a565-7d563607d30c',
      ]
      progress_bar = ProgressBar.create(total: incorrigibles.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      note = """
        This asset is causing trouble for our deriv creation.
        (see https://github.com/sciencehistory/scihist_digicoll/issues/2306#issuecomment-1671923288 )
      """.gsub(/\s/," ")
      Asset.transaction do
        incorrigibles.each do |uuid|
          Asset.find(uuid).update!({suppress_ocr: true, ocr_admin_note: note })
          progress_bar.increment
        end
      end
    end
  end
end
