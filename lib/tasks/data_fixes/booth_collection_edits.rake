namespace :scihist do
  namespace :data_fixes do
    desc """
      Attempts to publish certain items in the Booth collection; adds extents too.
      heroku run rake scihist:data_fixes:booth_collection_edits     --app scihist-digicoll-staging
      heroku run rake scihist:data_fixes:booth_collection_publishes --app scihist-digicoll-staging

    """

    task :booth_collection_edits => :environment do
      errors = []

      extents.keys.each do |friendlier_id|
        errors << "Could not find work #{friendlier_id}" if  Work.find_by_friendlier_id(friendlier_id).nil?
      end

      progress_bar = ProgressBar.create(total: extents.keys.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          Work.where(friendlier_id: extents.keys).find_each(batch_size: 10) do |work|
            unless work.update(extent: extents[work.friendlier_id])
              errors << "Problems updating extent of work #{friendlier_id}"
              progress_bar.increment
              next
            end
            progress_bar.increment
          end
        end
      end
      puts errors.join("; ")
    end

    task :booth_collection_publishes => :environment do
      errors = []

      desired_published_status.keys.each do |friendlier_id|
        errors << "Could not find work #{friendlier_id}" if  Work.find_by_friendlier_id(friendlier_id).nil?
      end

      progress_bar = ProgressBar.create(total: desired_published_status.keys.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          Work.where(friendlier_id: desired_published_status.keys).find_each(batch_size: 10) do |work|
            unless work.update(published: desired_published_status[work.friendlier_id])
              errors << "Problems publishing work #{friendlier_id}"
              progress_bar.increment
              next
            end
            progress_bar.increment
          end
        end
      end
      puts errors.join("; ")
    end

    def desired_published_status
      {
      '10mj26d'=>true,
      '197tf1q'=>false,
      '1ercfb2'=>true,
      '1ezhag7'=>true,
      '1ghqg4p'=>false,
      '1gyh1nl'=>true,
      '1jqh2nh'=>false,
      '1jqtatf'=>true,
      '1o4yzlk'=>true,
      '1r6d277'=>false,
      '1rejlgw'=>true,
      '1uerldi'=>true,
      '1utl2yy'=>true,
      '1vog6vd'=>true,
      '23ss6yn'=>true,
      '24r6v6y'=>true,
      '2cye6fh'=>true,
      '2dzorzw'=>true,
      '2een6yq'=>true,
      '2f94ipb'=>true,
      '2fle64n'=>false,
      '2njjk8l'=>true,
      '2tl95qi'=>true,
      '2u3lck1'=>true,
      '2wlr07n'=>false,
      '2yhdb24'=>true,
      '2zad1wu'=>true,
      '30d0w57'=>true,
      '33qq6ad'=>true,
      '33r26j9'=>true,
      '3dwxl1v'=>false,
      '3g107tb'=>true,
      '3hby9g8'=>true,
      '3x36keu'=>true,
      '3z9wwqz'=>false,
      '45fy7au'=>true,
      '4demxx0'=>true,
      '4gkonxy'=>true,
      '4n2aq0n'=>false,
      '4o7tujb'=>true,
      '4qe31v7'=>false,
      '4s7w0ee'=>true,
      '4txr25q'=>true,
      '4v0el8h'=>true,
      '5089zoy'=>true,
      '57rqt67'=>true,
      '5myaqgq'=>true,
      '5sehkin'=>false,
      '5ze65ky'=>false,
      '62dyp95'=>true,
      '656gw1h'=>false,
      '65kl3ha'=>true,
      '65vkq45'=>true,
      '6eju4an'=>true,
      '6nhcynv'=>true,
      '6ua8jwb'=>false,
      '6vfqjgy'=>true,
      '6zl6tvt'=>false,
      '72pq3z4'=>false,
      '77cwmhd'=>false,
      '77lenm1'=>true,
      '7bi2x32'=>true,
      '7fmggmu'=>true,
      '7hofwad'=>true,
      '7jaw5fm'=>true,
      '7l50rkc'=>false,
      '7ow52fr'=>false,
      '7pkc555'=>true,
      '7svtwen'=>false,
      '7z5inh0'=>false,
      '7zm0yah'=>true,
      '81b0vxf'=>false,
      '821x60k'=>true,
      '8264aei'=>false,
      '832ohi8'=>false,
      '84d6eef'=>false,
      '84fwjqp'=>true,
      '85unrzk'=>true,
      '88u2es8'=>true,
      '8gzf1fq'=>false,
      '8k1x8fh'=>true,
      '8koly8b'=>true,
      '8l179f4'=>false,
      '8nnyguk'=>false,
      '8qa0cst'=>false,
      '8t8bcch'=>false,
      '8x56b3e'=>false,
      '8y6vpm4'=>false,
      '90aebrt'=>true,
      '9204eo1'=>true,
      '9exhay6'=>false,
      '9h4cd3p'=>true,
      '9wi6n0j'=>true,
      'a1izm0t'=>true,
      'a1sdtup'=>true,
      'a68408e'=>true,
      'aeger4e'=>false,
      'aegmlfd'=>false,
      'ahcpk1j'=>true,
      'akzxrxb'=>false,
      'amww9xs'=>true,
      'aokldvp'=>false,
      'atvlzv4'=>false,
      'auzn67j'=>true,
      'b0m0r4e'=>false,
      'b2316ki'=>true,
      'bakyr0u'=>true,
      'bc4nm4r'=>true,
      'bc4sq1u'=>true,
      'bhgiho5'=>false,
      'bhoxkcw'=>true,
      'bjjkf16'=>true,
      'bkd1vmh'=>true,
      'bkmhxye'=>true,
      'bmudph1'=>true,
      'bs00lc7'=>false,
      'bsuxl7b'=>false,
      'bwvq4kd'=>false,
      'bxu5jcj'=>true,
      'bxy4pl4'=>true,
      'byjqznl'=>true,
      'ccd6lpr'=>true,
      'cdxodla'=>true,
      'cfds5lq'=>true,
      'ciuaxjs'=>true,
      'cmbwh1j'=>false,
      'czktseq'=>true,
      'd1uo74o'=>true,
      'd5rhr44'=>false,
      'd8hwrz6'=>false,
      'dangiyr'=>false,
      'dl6llu6'=>true,
      'dm6r9ay'=>true,
      'dniniqc'=>true,
      'dt7iegn'=>false,
      'duqlk9e'=>true,
      'dw7atl3'=>true,
      'dx5m4lo'=>true,
      'e0it9g3'=>true,
      'e0zg79x'=>true,
      'e8glix2'=>false,
      'ebf2ked'=>true,
      'ee5xdqk'=>false,
      'efm1vb6'=>true,
      'eol36ex'=>true,
      'er64yll'=>false,
      'eudxdkg'=>true,
      'exp6fjh'=>true,
      'exrftx0'=>false,
      'f4ww0i1'=>false,
      'f5glv9p'=>false,
      'f7ehf15'=>true,
      'fbi0c9b'=>true,
      'fdhm5j9'=>true,
      'fmwqms4'=>true,
      'fo72jhr'=>true,
      'foh3c53'=>true,
      'fqtw7ll'=>true,
      'fydbpm8'=>true,
      'fyso4o9'=>true,
      'fzp5rn5'=>true,
      'g3zks4g'=>true,
      'g48yqg0'=>true,
      'g7wgxwv'=>true,
      'g9dl6h5'=>true,
      'gb3lczs'=>false,
      'gedtbvv'=>true,
      'gfdq0pd'=>true,
      'ghq7859'=>false,
      'gres02i'=>true,
      'gtmgqqm'=>true,
      'gwu4yqo'=>true,
      'gzr3mio'=>true,
      'h2646uz'=>true,
      'h7j2htv'=>true,
      'ha07bmf'=>false,
      'ha7m2b5'=>true,
      'hb4l4j3'=>true,
      'hf570p0'=>true,
      'hfmst72'=>true,
      'hhhp495'=>true,
      'hw2ymbr'=>true,
      'i1fumf5'=>true,
      'i3qgbo0'=>true,
      'i3xqet1'=>false,
      'i4k7i6b'=>true,
      'i4z4ezl'=>false,
      'i6rt4gp'=>false,
      'i79t80o'=>false,
      'i9g2u3c'=>true,
      'idcexhf'=>true,
      'if23wa7'=>true,
      'ihb9slo'=>true,
      'ipu28p8'=>true,
      'isovra0'=>true,
      'iucx0ti'=>true,
      'iwbp4pc'=>true,
      'j55namd'=>true,
      'j7i00sw'=>false,
      'j98ukdy'=>true,
      'jde1bn9'=>false,
      'jdkuc0u'=>false,
      'jdlxt0l'=>true,
      'jfghtj7'=>true,
      'jixdbvg'=>true,
      'jyihbv2'=>true,
      'k0lxixk'=>true,
      'k4mjego'=>true,
      'kdk1n9x'=>true,
      'kgeiql7'=>true,
      'kha3g6d'=>true,
      'ki6zvt1'=>true,
      'kjzq5sx'=>true,
      'kszr2ul'=>true,
      'ktpjt33'=>true,
      'l2hqn2o'=>true,
      'l73mssf'=>false,
      'l8fp1fs'=>true,
      'ljed9mk'=>true,
      'ljxamoy'=>true,
      'lme4qyn'=>true,
      'lqxm9ua'=>true,
      'lr7dwhl'=>true,
      'm4p09hr'=>true,
      'm4u1n1j'=>true,
      'm6ddg7t'=>false,
      'ma65uy0'=>false,
      'mashmj9'=>false,
      'mer100s'=>true,
      'mqux06j'=>true,
      'muggex7'=>true,
      'mxrijou'=>true,
      'myitmhi'=>false,
      'n1piw4h'=>true,
      'n5t8nhk'=>true,
      'n8jrr75'=>false,
      'n8rgw0r'=>true,
      'ncsjl5w'=>true,
      'nj4a75x'=>false,
      'njnlbz1'=>true,
      'nqrtps3'=>false,
      'nslexdf'=>true,
      'nwo8kqz'=>true,
      'o04e2p3'=>true,
      'o10muzh'=>true,
      'o3w4q3e'=>true,
      'o4nuf9m'=>true,
      'o59h9it'=>true,
      'o63j33w'=>true,
      'o6ftflb'=>false,
      'o9jwxys'=>false,
      'ob3tote'=>true,
      'ofjz751'=>false,
      'ogztzeq'=>true,
      'omkjea4'=>true,
      'ot2y4l5'=>true,
      'oxcbrip'=>false,
      'oy8qthc'=>true,
      'oznthg9'=>true,
      'p2zqqqh'=>true,
      'p456eft'=>false,
      'p80xxp9'=>true,
      'p9axx7i'=>false,
      'pastnl8'=>true,
      'pbhvlmd'=>true,
      'pctymqr'=>true,
      'pg2ki9y'=>false,
      'pkbqbqz'=>false,
      'pkziwcl'=>true,
      'pl1gx0i'=>true,
      'ppa95zn'=>true,
      'pq82gi2'=>true,
      'pweohxe'=>true,
      'q0qbm38'=>false,
      'q4z7qne'=>true,
      'qdgfliq'=>true,
      'qfybf3a'=>true,
      'qkfs9bd'=>true,
      'qsdq4ix'=>true,
      'qvnl15o'=>false,
      'qvowckd'=>true,
      'qw3bk1n'=>false,
      'qw628gp'=>true,
      'qw6o4j7'=>false,
      'r1mtuwo'=>true,
      'r2t5vbs'=>true,
      'ra76ypu'=>true,
      'raw8up9'=>true,
      'rbr2fuq'=>true,
      'rbzlhbo'=>false,
      'rf97nsa'=>true,
      'rlbrfgv'=>false,
      'rtvqba0'=>true,
      'rv4gi63'=>true,
      's16pfcv'=>false,
      's1hmlbi'=>true,
      's2p82ho'=>true,
      's3ehq37'=>false,
      's3l81dv'=>false,
      's3o7sw9'=>true,
      's7d5ulv'=>true,
      's7yaems'=>true,
      's8yguyq'=>true,
      's93eeay'=>false,
      's9lze3z'=>true,
      'se4gw5b'=>true,
      'sfk3235'=>true,
      'ssdqv3l'=>true,
      'sspgrgd'=>true,
      'ssx4mym'=>true,
      'syep54r'=>false,
      't2jb3df'=>false,
      't39uj12'=>true,
      't80zmib'=>true,
      't8jqp52'=>true,
      'ta13yu2'=>false,
      'tc31ywv'=>true,
      'tf9sfsp'=>true,
      'thgf8g9'=>false,
      'ti5ls3e'=>true,
      'tlbp17v'=>false,
      'tnhai4l'=>true,
      'truandq'=>true,
      'tuo0hx5'=>true,
      'u7hr4g2'=>false,
      'u9k1gr5'=>false,
      'ucsst5f'=>false,
      'ujjrg86'=>false,
      'us1tcd1'=>true,
      'uzvzlgp'=>true,
      'v3uh44i'=>false,
      'v8vhh6v'=>true,
      'vcp9h5t'=>false,
      'vn3c19e'=>true,
      'vqqyhv1'=>true,
      'vt1p88d'=>true,
      'vyrwmk2'=>true,
      'w55wm4k'=>false,
      'waj2v62'=>false,
      'wb8d9xu'=>true,
      'wbsqfgs'=>false,
      'wc26p9w'=>false,
      'we7kwvm'=>true,
      'wegcetb'=>true,
      'whn76yq'=>false,
      'whu59tj'=>true,
      'wi8u5py'=>true,
      'wijuf2w'=>true,
      'wls4pq2'=>true,
      'woa96qm'=>false,
      'wrasddn'=>true,
      'wtoxfx9'=>true,
      'wv12xyo'=>true,
      'ww4r41h'=>true,
      'wy7ksyl'=>false,
      'wyb7s20'=>false,
      'x4lw9y5'=>true,
      'x7mbsgt'=>false,
      'x9yw6nu'=>true,
      'xc7fv4x'=>true,
      'xd62u3y'=>false,
      'xg0rkia'=>true,
      'xjs9drs'=>true,
      'xnu6hax'=>true,
      'xqfcdeu'=>true,
      'xvbba76'=>false,
      'xyvurxz'=>false,
      'y2685a9'=>true,
      'y324fqg'=>true,
      'y8kw7r7'=>false,
      'ya6oh2d'=>true,
      'ycgsdv6'=>false,
      'ychceyz'=>false,
      'yiz7m0p'=>true,
      'yldfia6'=>false,
      'yupwyyl'=>true,
      'yv5zhqe'=>false,
      'zcunc05'=>false,
      'zdgfasg'=>true,
      'zg3mqde'=>true,
      'znch7su'=>true,
      'zrsqqca'=>true,
      'zwtyoe9'=>true,
      'zxkzmbb'=>true,
      }
    end

    def extents
      {
      '10mj26d'=>'20 cm W x 25 cm H',
      '197tf1q'=>'14 cm W x 21.4 cm H',
      '1ercfb2'=>'24.7 cm W x 20.5 cm H',
      '1ezhag7'=>'12.5 cm W x 20.2 cm H',
      '1ghqg4p'=>'13 cm W x 7.1 cm H',
      '1gyh1nl'=>'12 cm W x 20.3 cm H',
      '1jqh2nh'=>'19.7 cm W x 25.7 cm H',
      '1jqtatf'=>'19.5 cm W x 25.5 cm H',
      '1o4yzlk'=>'12.6 cm W x 20.3 cm H',
      '1r6d277'=>'14.3 cm W x 22.4 cm H',
      '1rejlgw'=>'12.7 cm W x 20.1 cm H',
      '1uerldi'=>'12.6 cm W x 20.6 cm H',
      '1utl2yy'=>'20 cm W x 25 cm H',
      '1vog6vd'=>'20 cm W x 25 cm H',
      '23ss6yn'=>'20 cm W x 25 cm H',
      '24r6v6y'=>'14.7 cm W x 23.7 cm H',
      '2cye6fh'=>'20 cm W x 25 cm H',
      '2dzorzw'=>'20 cm W x 25 cm H',
      '2een6yq'=>'20 cm W x 25 cm H',
      '2f94ipb'=>'16.2 cm W x 23.6 cm H',
      '2fle64n'=>'21 cm W x 25 cm H',
      '2njjk8l'=>'19.5 cm W x 24.5 cm H',
      '2tl95qi'=>'20 cm W x 25 cm H',
      '2u3lck1'=>'20 cm W x 24.8 cm H',
      '2wlr07n'=>'20.1 cm W x 24.5 cm H',
      '2yhdb24'=>'12.7 cm W x 25.4 cm H',
      '2zad1wu'=>'19.8 cm W x 25.2 cm H',
      '30d0w57'=>'12.7 cm W x 20.5 cm H',
      '33qq6ad'=>'20 cm W x 32 cm H',
      '33r26j9'=>'12.5 cm W x 20 cm H',
      '3dwxl1v'=>'19.8 cm W x 24.3 cm H',
      '3g107tb'=>'20.1 cm W x 27.6 cm H',
      '3hby9g8'=>'19.7 cm W x 24.8 cm H',
      '3x36keu'=>'12.3 cm W x 20 cm H',
      '3z9wwqz'=>'14 cm W x 20.1 cm H',
      '45fy7au'=>'12 cm W x 20 cm H',
      '4demxx0'=>'20.3 cm W x 25.6 cm H',
      '4gkonxy'=>'20.4 cm W x 25.1 cm H',
      '4n2aq0n'=>'19.6 cm W x 24.8 cm H',
      '4o7tujb'=>'13 cm W x 21 cm H',
      '4qe31v7'=>'21 cm W x 20.1 cm H',
      '4s7w0ee'=>'12.9 cm W x 20.5 cm H',
      '4txr25q'=>'20 cm W x 25 cm H',
      '4v0el8h'=>'20 cm W x 32 cm H',
      '5089zoy'=>'19.7 cm W x 25 cm H',
      '57rqt67'=>'20 cm W x 25 cm H',
      '5myaqgq'=>'13.2 cm W x 20.4 cm H',
      '5sehkin'=>'14.3 cm W x 33.1 cm H',
      '5ze65ky'=>'13.8 cm W x 16.4 cm H',
      '62dyp95'=>'14 cm W x 21.6 cm H',
      '656gw1h'=>'11 cm W x 14.4 cm H',
      '65kl3ha'=>'13.5 cm W x 22 cm H',
      '65vkq45'=>'20 cm W x 25 cm H',
      '6eju4an'=>'19.7 cm W x 25 cm H',
      '6nhcynv'=>'12.6 cm W x 20.5 cm H',
      '6ua8jwb'=>'13.8 cm W x 21.6 cm H',
      '6vfqjgy'=>'21.4 cm W x 27.8 cm H',
      '6zl6tvt'=>'12.7 cm W x 20.3 cm H',
      '72pq3z4'=>'19.5 cm W x 24.8 cm H',
      '77cwmhd'=>'24.4 cm W x 24.8 cm H',
      '77lenm1'=>'12.5 cm W x 20.3 cm H',
      '7bi2x32'=>'20.3 cm W x 26.5 cm H',
      '7fmggmu'=>'13.8 cm W x 21.3 cm H',
      '7hofwad'=>'11.5 cm W x 17.8 cm H',
      '7jaw5fm'=>'11.2 cm W x 17 cm H',
      '7l50rkc'=>'19.4 cm W x 23.6 cm H',
      '7ow52fr'=>'18 cm W x 20.4 cm H',
      '7pkc555'=>'14.6 cm W x 23.7 cm H',
      '7svtwen'=>'20 cm W x 15.7 cm H',
      '7z5inh0'=>'13 cm W x 20 cm H',
      '7zm0yah'=>'28.1 cm W x 22 cm H',
      '81b0vxf'=>'19 cm W x 25 cm H',
      '821x60k'=>'12.4 cm W x 20.3 cm H',
      '8264aei'=>'22.5 cm W x 22.5 cm H',
      '832ohi8'=>'14.6 cm W x 20.2 cm H',
      '84d6eef'=>'13.8 cm W x 16.6 cm H',
      '84fwjqp'=>'12.5 cm W x 19.9 cm H',
      '85unrzk'=>'12.5 cm W x 20 cm H',
      '88u2es8'=>'11.4 cm W x 18 cm H',
      '8gzf1fq'=>'13.2 cm W x 21 cm H',
      '8k1x8fh'=>'13.2 cm W x 21.6 cm H',
      '8koly8b'=>'12.7 cm W x 20.5 cm H',
      '8l179f4'=>'20.5 cm W x 25.4 cm H',
      '8nnyguk'=>'22.4 cm W x 25 cm H',
      '8qa0cst'=>'12.6 cm W x 20.3 cm H',
      '8t8bcch'=>'14.7 cm W x 20.8 cm H',
      '8x56b3e'=>'13.3 cm W x 19.9 cm H',
      '8y6vpm4'=>'13.8 cm W x 21.6 cm H',
      '90aebrt'=>'19.7 cm W x 25 cm H',
      '9204eo1'=>'14 cm W x 20.4 cm H',
      '9exhay6'=>'22.5 cm W x 14 cm H',
      '9h4cd3p'=>'12.8 cm W x 20 cm H',
      '9wi6n0j'=>'13.5 cm W x 21.5 cm H',
      'a1izm0t'=>'20 cm W x 25 cm H',
      'a1sdtup'=>'12.8 cm W x 20 cm H',
      'a68408e'=>'12.7 cm W x 20.5 cm H',
      'aeger4e'=>'20 cm W x 20 cm H',
      'aegmlfd'=>'17.5 cm W x 26 cm H',
      'ahcpk1j'=>'20 cm W x 32 cm H',
      'akzxrxb'=>'14.6 cm W x 25 cm H',
      'amww9xs'=>'25 cm W x 20 cm H',
      'aokldvp'=>'19.9 cm W x 23 cm H',
      'atvlzv4'=>'25.7 cm W x 23.5 cm H',
      'auzn67j'=>'20 cm W x 32 cm H',
      'b0m0r4e'=>'22.4 cm W x 25 cm H',
      'b2316ki'=>'12.5 cm W x 20 cm H',
      'bakyr0u'=>'25.1 cm W x 20 cm H',
      'bc4nm4r'=>'24.5 cm W x 19.5 cm H',
      'bc4sq1u'=>'12.5 cm W x 20 cm H',
      'bhgiho5'=>'13.7 cm W x 21.5 cm H',
      'bhoxkcw'=>'24.8 cm W x 20.5 cm H',
      'bjjkf16'=>'21.1 cm W x 27 cm H',
      'bkd1vmh'=>'20 cm W x 25.1 cm H',
      'bkmhxye'=>'20 cm W x 25.2 cm H',
      'bmudph1'=>'25.2 cm W x 29.8 cm H',
      'bs00lc7'=>'13.7 cm W x 21.5 cm H',
      'bsuxl7b'=>'15.5 cm W x 14.6 cm H',
      'bwvq4kd'=>'13.8 cm W x 21.6 cm H',
      'bxu5jcj'=>'19.5 cm W x 25.3 cm H',
      'bxy4pl4'=>'19.9 cm W x 25.5 cm H',
      'byjqznl'=>'16 cm W x 25.1 cm H',
      'ccd6lpr'=>'20 cm W x 25 cm H',
      'cdxodla'=>'20 cm W x 32 cm H',
      'cfds5lq'=>'13.2 cm W x 20.5 cm H',
      'ciuaxjs'=>'19.7 cm W x 25 cm H',
      'cmbwh1j'=>'22.5 cm W x 29 cm H',
      'czktseq'=>'12.5 cm W x 20.3 cm H',
      'd1uo74o'=>'12.4 cm W x 22.5 cm H',
      'd5rhr44'=>'8.2 cm W x 17 cm H',
      'd8hwrz6'=>'19.5 cm W x 27.5 cm H',
      'dangiyr'=>'14.4 cm W x 22.4 cm H',
      'dl6llu6'=>'12.9 cm W x 30.3 cm H',
      'dm6r9ay'=>'20.3 cm W x 25 cm H',
      'dniniqc'=>'26.5 cm W x 20.8 cm H',
      'dt7iegn'=>'20 cm W x 24.7 cm H',
      'duqlk9e'=>'14 cm W x 22 cm H',
      'dw7atl3'=>'12 cm W x 19.5 cm H',
      'dx5m4lo'=>'20 cm W x 25 cm H',
      'e0it9g3'=>'12.5 cm W x 20.5 cm H',
      'e0zg79x'=>'12.5 cm W x 20.3 cm H',
      'e8glix2'=>'20 cm W x 27 cm H',
      'ebf2ked'=>'19.7 cm W x 25 cm H',
      'ee5xdqk'=>'13.8 cm W x 21.5 cm H',
      'efm1vb6'=>'12.5 cm W x 20 cm H',
      'eol36ex'=>'19.5 cm W x 24.8 cm H',
      'er64yll'=>'10.7 cm W x 6.3 cm H',
      'eudxdkg'=>'12.2 cm W x 19.7 cm H',
      'exp6fjh'=>'22.2 cm W x 28 cm H',
      'exrftx0'=>'17.4 cm W x 21.1 cm H',
      'f4ww0i1'=>'20 cm W x 25 cm H',
      'f5glv9p'=>'20 cm W x 26.5 cm H',
      'f7ehf15'=>'13.5 cm W x 20.9 cm H',
      'fbi0c9b'=>'20.2 cm W x 25.4 cm H',
      'fdhm5j9'=>'19.7 cm W x 25 cm H',
      'fmwqms4'=>'10 cm W x 15.3 cm H',
      'fo72jhr'=>'19.5 cm W x 25 cm H',
      'foh3c53'=>'12.6 cm W x 20.3 cm H',
      'fqtw7ll'=>'12.4 cm W x 19.8 cm H',
      'fydbpm8'=>'14.2 cm W x 23.5 cm H',
      'fyso4o9'=>'21.4 cm W x 27.8 cm H',
      'fzp5rn5'=>'19.7 cm W x 25 cm H',
      'g3zks4g'=>'12.3 cm W x 20.5 cm H',
      'g48yqg0'=>'19.7 cm W x 24.9 cm H',
      'g7wgxwv'=>'12.6 cm W x 20.6 cm H',
      'g9dl6h5'=>'12.5 cm W x 22.9 cm H',
      'gb3lczs'=>'13.8 cm W x 21.6 cm H',
      'gedtbvv'=>'16.5 cm W x 23.4 cm H',
      'gfdq0pd'=>'26 cm W x 20.3 cm H',
      'ghq7859'=>'19.5 cm W x 26 cm H',
      'gres02i'=>'20.3 cm W x 19 cm H',
      'gtmgqqm'=>'20 cm W x 25 cm H',
      'gwu4yqo'=>'20 cm W x 24.9 cm H',
      'gzr3mio'=>'19.5 cm W x 24.8 cm H',
      'h2646uz'=>'14.3 cm W x 22.5 cm H',
      'h7j2htv'=>'14 cm W x 22.1 cm H',
      'ha07bmf'=>'13 cm W x 7.5 cm H',
      'ha7m2b5'=>'22 cm W x 25.3 cm H',
      'hb4l4j3'=>'11.1 cm W x 17.4 cm H',
      'hf570p0'=>'14.2 cm W x 23.7 cm H',
      'hfmst72'=>'11.1 cm W x 17 cm H',
      'hhhp495'=>'20 cm W x 25 cm H',
      'hw2ymbr'=>'12.2 cm W x 19.5 cm H',
      'i1fumf5'=>'12 cm W x 19.5 cm H',
      'i3qgbo0'=>'12.9 cm W x 20.5 cm H',
      'i3xqet1'=>'20.2 cm W x 28 cm H',
      'i4k7i6b'=>'11.5 cm W x 18 cm H',
      'i4z4ezl'=>'13 cm W x 20 cm H',
      'i6rt4gp'=>'15.5 cm W x 23 cm H',
      'i79t80o'=>'12.6 cm W x 20 cm H',
      'i9g2u3c'=>'15.2 cm W x 24.2 cm H',
      'idcexhf'=>'11.5 cm W x 18.4 cm H',
      'if23wa7'=>'12.5 cm W x 20 cm H',
      'ihb9slo'=>'12.6 cm W x 20.1 cm H',
      'ipu28p8'=>'19.5 cm W x 24.8 cm H',
      'isovra0'=>'19.9 cm W x 25.4 cm H',
      'iucx0ti'=>'13.1 cm W x 20.5 cm H',
      'iwbp4pc'=>'20.3 cm W x 25.5 cm H',
      'j55namd'=>'13.5 cm W x 22.8 cm H',
      'j7i00sw'=>'12.5 cm W x 13.4 cm H',
      'j98ukdy'=>'19.5 cm W x 25 cm H',
      'jde1bn9'=>'13.2 cm W x 23 cm H',
      'jdkuc0u'=>'13 cm W x 7.5 cm H',
      'jdlxt0l'=>'12.6 cm W x 20.3 cm H',
      'jfghtj7'=>'12.6 cm W x 20.5 cm H',
      'jixdbvg'=>'20 cm W x 25 cm H',
      'jyihbv2'=>'20 cm W x 25 cm H',
      'k0lxixk'=>'14.3 cm W x 20.3 cm H',
      'k4mjego'=>'13 cm W x 20.4 cm H',
      'kdk1n9x'=>'13.5 cm W x 22 cm H',
      'kgeiql7'=>'12.6 cm W x 21.5 cm H',
      'kha3g6d'=>'20 cm W x 25 cm H',
      'ki6zvt1'=>'20 cm W x 23.5 cm H',
      'kjzq5sx'=>'14 cm W x 21.7 cm H',
      'kszr2ul'=>'20.4 cm W x 25.4 cm H',
      'ktpjt33'=>'20 cm W x 25 cm H',
      'l2hqn2o'=>'12.5 cm W x 20.3 cm H',
      'l73mssf'=>'19.4 cm W x 31.7 cm H',
      'l8fp1fs'=>'19.5 cm W x 25.1 cm H',
      'ljed9mk'=>'12.9 cm W x 21.3 cm H',
      'ljxamoy'=>'12.9 cm W x 20.3 cm H',
      'lme4qyn'=>'21.5 cm W x 27 cm H',
      'lqxm9ua'=>'11.1 cm W x 17.9 cm H',
      'lr7dwhl'=>'14.7 cm W x 23.7 cm H',
      'm4p09hr'=>'19.5 cm W x 24.9 cm H',
      'm4u1n1j'=>'12.6 cm W x 20.1 cm H',
      'm6ddg7t'=>'20 cm W x 24.3 cm H',
      'ma65uy0'=>'21.3 cm W x 17.1 cm H',
      'mashmj9'=>'20 cm W x 12.5 cm H',
      'mer100s'=>'20.5 cm W x 25.4 cm H',
      'mqux06j'=>'25.9 cm W x 20.3 cm H',
      'muggex7'=>'14.3 cm W x 22.3 cm H',
      'mxrijou'=>'14.4 cm W x 24.1 cm H',
      'myitmhi'=>'14.3 cm W x 22.4 cm H',
      'n1piw4h'=>'20.5 cm W x 25 cm H',
      'n5t8nhk'=>'14.5 cm W x 21 cm H',
      'n8jrr75'=>'19.8 cm W x 23.4 cm H',
      'n8rgw0r'=>'25.9 cm W x 20.3 cm H',
      'ncsjl5w'=>'12.7 cm W x 20.5 cm H',
      'nj4a75x'=>'12.2 cm W x 13 cm H',
      'njnlbz1'=>'13.8 cm W x 21.4 cm H',
      'nqrtps3'=>'13.8 cm W x 21.6 cm H',
      'nslexdf'=>'12.5 cm W x 20.5 cm H',
      'nw0789v'=>'20.4 cm W x 7.5 cm H',
      'nwo8kqz'=>'12.5 cm W x 20.3 cm H',
      'o04e2p3'=>'12 cm W x 27.7 cm H',
      'o10muzh'=>'19.7 cm W x 24.5 cm H',
      'o3w4q3e'=>'12.7 cm W x 20.3 cm H',
      'o4nuf9m'=>'20 cm W x 20.3 cm H',
      'o59h9it'=>'14.2 cm W x 23.2 cm H',
      'o63j33w'=>'19.6 cm W x 24.5 cm H',
      'o6ftflb'=>'17.4 cm W x 17 cm H',
      'o9jwxys'=>'14.4 cm W x 22.4 cm H',
      'ob3tote'=>'20.2 cm W x 25.5 cm H',
      'ofjz751'=>'13.3 cm W x 19.9 cm H',
      'ogztzeq'=>'12.5 cm W x 20.1 cm H',
      'omkjea4'=>'21.4 cm W x 26.5 cm H',
      'ot2y4l5'=>'20 cm W x 25 cm H',
      'oxcbrip'=>'13.8 cm W x 21.5 cm H',
      'oy8qthc'=>'13.6 cm W x 21.7 cm H',
      'oznthg9'=>'11.4 cm W x 17.3 cm H',
      'p2zqqqh'=>'20.2 cm W x 26.5 cm H',
      'p456eft'=>'12.5 cm W x 20.1 cm H',
      'p80xxp9'=>'13.1 cm W x 20.6 cm H',
      'p9axx7i'=>'20 cm W x 28 cm H',
      'pastnl8'=>'21 cm W x 34.3 cm H',
      'pbhvlmd'=>'13.5 cm W x 22 cm H',
      'pctymqr'=>'20.1 cm W x 25.4 cm H',
      'pg2ki9y'=>'13.8 cm W x 21.6 cm H',
      'pkbqbqz'=>'19.6 cm W x 24.4 cm H',
      'pkziwcl'=>'12.5 cm W x 20.2 cm H',
      'pl1gx0i'=>'23.9 cm W x 29.2 cm H',
      'ppa95zn'=>'12.5 cm W x 20.2 cm H',
      'pq82gi2'=>'10.1 cm W x 16 cm H',
      'pweohxe'=>'20 cm W x 25 cm H',
      'q0qbm38'=>'14.5 cm W x 20.7 cm H',
      'q4z7qne'=>'12.6 cm W x 20.5 cm H',
      'qdgfliq'=>'20.4 cm W x 25.3 cm H',
      'qfybf3a'=>'20.2 cm W x 25.4 cm H',
      'qkfs9bd'=>'12.5 cm W x 19.9 cm H',
      'qsdq4ix'=>'12.5 cm W x 20 cm H',
      'qvnl15o'=>'13 cm W x 7.5 cm H',
      'qvowckd'=>'20.2 cm W x 25.3 cm H',
      'qw3bk1n'=>'13.4 cm W x 21.2 cm H',
      'qw628gp'=>'22 cm W x 28.2 cm H',
      'qw6o4j7'=>'13.8 cm W x 21.5 cm H',
      'r1mtuwo'=>'12.6 cm W x 20.3 cm H',
      'r2t5vbs'=>'19.7 cm W x 16.5 cm H',
      'ra76ypu'=>'20 cm W x 25 cm H',
      'raw8up9'=>'20 cm W x 24 cm H',
      'rbr2fuq'=>'19.7 cm W x 25 cm H',
      'rbzlhbo'=>'13.5 cm W x 20.4 cm H',
      'rf97nsa'=>'19.7 cm W x 25 cm H',
      'rlbrfgv'=>'22.4 cm W x 25 cm H',
      'rtvqba0'=>'14 cm W x 20.5 cm H',
      'rv4gi63'=>'12.6 cm W x 21.4 cm H',
      's16pfcv'=>'11.5 cm W x 17 cm H',
      's1hmlbi'=>'12.8 cm W x 20.2 cm H',
      's2p82ho'=>'20 cm W x 25 cm H',
      's3ehq37'=>'19.5 cm W x 25 cm H',
      's3l81dv'=>'19.2 cm W x 28.9 cm H',
      's3o7sw9'=>'20 cm W x 25.2 cm H',
      's7d5ulv'=>'24.6 cm W x 20.2 cm H',
      's7yaems'=>'11.5 cm W x 6 cm H',
      's8yguyq'=>'24.5 cm W x 20.5 cm H',
      's93eeay'=>'15.7 cm W x 22 cm H',
      's9lze3z'=>'12.6 cm W x 20.4 cm H',
      'se4gw5b'=>'19.5 cm W x 24.5 cm H',
      'sfk3235'=>'11.4 cm W x 18 cm H',
      'ssdqv3l'=>'13.5 cm W x 22.6 cm H',
      'sspgrgd'=>'12.7 cm W x 20.5 cm H',
      'ssx4mym'=>'19.5 cm W x 28.4 cm H',
      'syep54r'=>'12.8 cm W x 19.5 cm H',
      't2jb3df'=>'17.4 cm W x 32.7 cm H',
      't39uj12'=>'20 cm W x 32 cm H',
      't80zmib'=>'19.5 cm W x 25 cm H',
      't8jqp52'=>'11.9 cm W x 19.5 cm H',
      'ta13yu2'=>'17.5 cm W x 10.8 cm H',
      'tc31ywv'=>'19.3 cm W x 25.2 cm H',
      'tf9sfsp'=>'20 cm W x 25 cm H',
      'thgf8g9'=>'21.2 cm W x 25.5 cm H',
      'ti5ls3e'=>'19.5 cm W x 25.3 cm H',
      'tlbp17v'=>'19.6 cm W x 19.9 cm H',
      'tnhai4l'=>'25.9 cm W x 20.3 cm H',
      'truandq'=>'12.6 cm W x 20 cm H',
      'tuo0hx5'=>'14.5 cm W x 20.3 cm H',
      'u7hr4g2'=>'19.5 cm W x 31.7 cm H',
      'u9k1gr5'=>'12.5 cm W x 20 cm H',
      'ucsst5f'=>'12.1 cm W x 20.2 cm H',
      'ujjrg86'=>'19.7 cm W x 24.6 cm H',
      'us1tcd1'=>'13 cm W x 20.2 cm H',
      'uzvzlgp'=>'20.1 cm W x 25 cm H',
      'v3uh44i'=>'13 cm W x 20 cm H',
      'v8vhh6v'=>'12.3 cm W x 20.4 cm H',
      'vcp9h5t'=>'19.7 cm W x 25 cm H',
      'vn3c19e'=>'20 cm W x 25 cm H',
      'vqqyhv1'=>'19.7 cm W x 25.1 cm H',
      'vt1p88d'=>'25.2 cm W x 20.4 cm H',
      'vyrwmk2'=>'19.7 cm W x 24.5 cm H',
      'w55wm4k'=>'12 cm W x 19.5 cm H',
      'waj2v62'=>'20 cm W x 24.4 cm H',
      'wb8d9xu'=>'20.1 cm W x 17.7 cm H',
      'wbsqfgs'=>'12.2 cm W x 20.1 cm H',
      'wc26p9w'=>'20.2 cm W x 22.5 cm H',
      'we7kwvm'=>'14.6 cm W x 22.5 cm H',
      'wegcetb'=>'14.5 cm W x 20.2 cm H',
      'whn76yq'=>'13.3 cm W x 19.9 cm H',
      'whu59tj'=>'16.5 cm W x 11 cm H',
      'wi8u5py'=>'19.5 cm W x 15.2 cm H',
      'wijuf2w'=>'19.5 cm W x 23.6 cm H',
      'wls4pq2'=>'20 cm W x 25 cm H',
      'woa96qm'=>'19.6 cm W x 25 cm H',
      'wrasddn'=>'20 cm W x 25.2 cm H',
      'wtoxfx9'=>'14.2 cm W x 23.5 cm H',
      'wv12xyo'=>'13.5 cm W x 22 cm H',
      'ww4r41h'=>'20 cm W x 25 cm H',
      'wy7ksyl'=>'13 cm W x 20.3 cm H',
      'wyb7s20'=>'18.5 cm W x 22.6 cm H',
      'x4lw9y5'=>'12.7 cm W x 20.2 cm H',
      'x7mbsgt'=>'20.9 cm W x 29.1 cm H',
      'x9yw6nu'=>'19.5 cm W x 25 cm H',
      'xc7fv4x'=>'19.8 cm W x 25 cm H',
      'xd62u3y'=>'15 cm W x 19.7 cm H',
      'xg0rkia'=>'19.7 cm W x 25 cm H',
      'xjs9drs'=>'19.7 cm W x 25.2 cm H',
      'xnu6hax'=>'19.6 cm W x 24.6 cm H',
      'xqfcdeu'=>'20 cm W x 25 cm H',
      'xvbba76'=>'195 cm W x 24.5 cm H',
      'xyvurxz'=>'14 cm W x 20 cm H',
      'y2685a9'=>'20 cm W x 25 cm H',
      'y324fqg'=>'13.5 cm W x 22 cm H',
      'y8kw7r7'=>'17 cm W x 11.5 cm H',
      'ya6oh2d'=>'24.9 cm W x 19.7 cm H',
      'ycgsdv6'=>'19.5 cm W x 26 cm H',
      'ychceyz'=>'19.5 cm W x 27.5 cm H',
      'yiz7m0p'=>'20 cm W x 26 cm H',
      'yldfia6'=>'13.8 cm W x 21.5 cm H',
      'yupwyyl'=>'20.3 cm W x 23 cm H',
      'yv5zhqe'=>'17.4 cm W x 21.3 cm H',
      'zcunc05'=>'21.5 cm W x 17.8 cm H',
      'zdgfasg'=>'14.5 cm W x 21.21 cm H',
      'zg3mqde'=>'21.6 cm W x 28 cm H',
      'znch7su'=>'19.5 cm W x 25.2 cm H',
      'zrsqqca'=>'14.5 cm W x 25.4 cm H',
      'zwtyoe9'=>'13 cm W x 21 cm H',
      'zxkzmbb'=>'13.5 cm W x 20.2 cm H',
    }
    end
  end
end
