namespace :scihist do
  namespace :data_fixes do
    desc "Genre adjustments, per https://github.com/sciencehistory/scihist_digicoll/issues/1275"
    task :fix_parent_child => :environment do
      adjustments = {
        'nv935287v'=>'7exqvau',
        'kh04dp72m'=>'7exqvau',
        'wh246s18x'=>'7exqvau',
        '8s45q881f'=>'7exqvau',
        '0c483j42m'=>'7exqvau',
        '8s45q8805'=>'7exqvau',
        '8910jt61f'=>'7exqvau',
        '5138jd856'=>'7exqvau',
        'br86b3609'=>'7exqvau',
        'p5547r43n'=>'7exqvau',
        '8623hx748'=>'7exqvau',
        '44558d32r'=>'7exqvau',
        'hq37vn58w'=>'7exqvau',
        '6w924b89c'=>'1jlzom2',
        'gh93gz533'=>'1jlzom2',
        'gb19f5896'=>'1jlzom2',
        '2r36tx60w'=>'1jlzom2',
        'mw22v550f'=>'1jlzom2',
        'fj236221c'=>'1jlzom2',
        '6w924b904'=>'1jlzom2',
        'mg74qm19x'=>'1jlzom2',
        '4m90dv57p'=>'1jlzom2',
        'k35694464'=>'3t9glog',
        'b5644r712'=>'3t9glog',
        'jw827b78m'=>'3t9glog',
        'd504rk513'=>'3t9glog',
        '736664674'=>'3t9glog',
        'sn009x98m'=>'3t9glog',
        'kd17cs98h'=>'3t9glog',
        '3t945q950'=>'3t9glog',
        'b2773v855'=>'3t9glog',
        '9s1616449'=>'3t9glog',
        'gt54kn23c'=>'3t9glog',
        'mc87pq441'=>'3t9glog',
        'h415p969t'=>'3t9glog',
        'dj52w485x'=>'3t9glog',
        'qv33rw787'=>'3t9glog',
        'jm214p31z'=>'3t9glog',
        'p8418n43w'=>'3t9glog',
        '3f462561b'=>'3t9glog',
        '8623hx837'=>'3t9glog',
        '9593tv319'=>'3t9glog',
        'rj430475k'=>'3t9glog',
        'c247ds26v'=>'3t9glog',
        'ms35t876b'=>'3t9glog',
        'fq977t95h'=>'3t9glog',
        '4m90dv74b'=>'3t9glog',
        'dr26xx51p'=>'3t9glog',
        'ft848q79c'=>'3t9glog',
        'ff365536r'=>'3t9glog',
        'ms35t877m'=>'3t9glog',
        'nv9353006'=>'3t9glog',
        '9p290959p'=>'3t9glog',
        'mc87pq43r'=>'3t9glog',
        '6395w730p'=>'3t9glog',
        'j9602077r'=>'3t9glog',
        '4j03cz88g'=>'3t9glog',
        'cv43nw997'=>'3t9glog',
        '5d86p042m'=>'3t9glog',
        '8p58pd074'=>'3t9glog',
        '9880vr12b'=>'3t9glog',
        'zg64tm15k'=>'3t9glog',
        '4x51hj16f'=>'3t9glog',
        'dz010q26z'=>'3t9glog',
        'kw52j8202'=>'3t9glog',
        'jh343s452'=>'3t9glog',
        'wp988j973'=>'3t9glog',
        'np193940q'=>'3t9glog',
        'st74cq62z'=>'3t9glog',
        'tq57nr181'=>'3t9glog',
        'ff365539k'=>'3t9glog',
        'pr76f356g'=>'3t9glog',
        'tt44pm955'=>'3t9glog',
        'hx11xf43r'=>'3t9glog',
        'cv43nw97p'=>'3t9glog',
        '3b591871b'=>'3t9glog',
        '6969z096b'=>'3t9glog',
        'gb19f596m'=>'3t9glog',
        'dn39x1713'=>'3t9glog',
        'cf95jb62q'=>'3t9glog',
        '7d278t14x'=>'3t9glog',
        'ff3655371'=>'3t9glog',
        'rv042t24x'=>'3t9glog',
        'pg15bf00v'=>'3t9glog',
        'ff3655389'=>'3t9glog',
        'mk61rh14s'=>'3t9glog',
        '5712m673w'=>'3t9glog',
        'wm117p206'=>'3t9glog',
        'zc77sq28d'=>'3t9glog',
        'xp68kg392'=>'3t9glog',
        'g445cd39f'=>'3t9glog',
        'ng451h71z'=>'3t9glog',
        '9z902z98p'=>'3t9glog',
        'v118rd69b'=>'3t9glog',
        'tq57nr199'=>'3t9glog',
        '1c18dg02h'=>'3t9glog',
        'fq977t947'=>'3t9glog',
        'br86b3791'=>'3t9glog',
        'pz50gw24h'=>'3t9glog',
        '1g05fb816'=>'3t9glog',
        '2b88qc35p'=>'3t9glog',
        'h989r353n'=>'3t9glog',
        'ng451h727'=>'3t9glog',
        'rj430476v'=>'3t9glog',
        'sf268527j'=>'3t9glog',
        '44558d527'=>'3t9glog',
        'qb98mf61z'=>'3t9glog',
        'rr171x32c'=>'3t9glog',
        'pc289j16h'=>'3t9glog',
        'cr56n110z'=>'3t9glog',
        'sx61dm41f'=>'3t9glog',
        'jh343s46b'=>'3t9glog',
        'f4752g877'=>'3t9glog',
        '5d86p043w'=>'3t9glog',
        'n009w233b'=>'dr2eycv',
        'zc77sq12h'=>'dr2eycv',
        'v118rd568'=>'dr2eycv',
        '3t945q80c'=>'dr2eycv',
        'pz50gw084'=>'dr2eycv',
        'ft848q651'=>'dr2eycv',
        '0c483j41b'=>'dr2eycv',
        'c821gj795'=>'dr2eycv',
        'c247ds15b'=>'dr2eycv',
        'bc386j20b'=>'dr2eycv',
        'bv73c0445'=>'dr2eycv',
        '9593tv166'=>'dr2eycv',
        '3t945q81n'=>'dr2eycv',
        'b2773v73c'=>'dr2eycv',
        'rn301139z'=>'dr2eycv',
        '6w924b82f'=>'dr2eycv',
        'w0892994f'=>'dr2eycv',
        'pc289j08t'=>'70evtk8',
        'q524jn85t'=>'70evtk8',
        'kw52j8113'=>'70evtk8',
        'pn89d663n'=>'70evtk8',
        'sn009x873'=>'70evtk8',
        'k3569434b'=>'70evtk8',
        '7m01bk74n'=>'70evtk8',
        '4f16c2874'=>'70evtk8',
        'cj82k7395'=>'70evtk8',
        '2v23vt41x'=>'70evtk8',
        'c247ds185'=>'70evtk8',
        'v405s944q'=>'70evtk8',
        '6108vb31r'=>'70evtk8',
        'js956f85s'=>'70evtk8',
        'q524jn863'=>'70evtk8',
        '6h440s484'=>'70evtk8',
        'xk81jk45p'=>'70evtk8',
        '2v23vt426'=>'70evtk8',
        'qf85nb36v'=>'70evtk8',
        'n583xv05f'=>'70evtk8',
        'zk51vg83r'=>'70evtk8',
        '6w924b87t'=>'70evtk8',
        '08612n63v'=>'70evtk8',
        '5d86p0292'=>'70evtk8',
        'z890rt33r'=>'70evtk8',
        '2j62s4901'=>'70evtk8',
        'dr26xx448'=>'70evtk8',
        'n583xt99h'=>'6lty65g',
        'x633f101s'=>'6lty65g',
        'z890rt26b'=>'6lty65g',
        '4q77fr36f'=>'6lty65g',
        'pk02c9767'=>'6lty65g',
        'ht24wj43h'=>'6lty65g',
        'qz20ss512'=>'6lty65g',
        'tb09j566n'=>'6lty65g',
        'ng451h549'=>'6lty65g',
        'f4752g75f'=>'nu07tat',
        'mc87pq27c'=>'nu07tat',
        'ww72bb49x'=>'nu07tat',
        'm039k489b'=>'nu07tat',
        '2j62s486f'=>'nu07tat',
        'j3860692c'=>'nu07tat',
        '4t64gn20s'=>'nu07tat',
        '8s45q8848'=>'mkfmshd',
        '5138jd86g'=>'mkfmshd',
        '5q47rn80n'=>'mkfmshd',
        '736664517'=>'mkfmshd',
        '8k71nh12g'=>'mkfmshd',
        'qf85nb32r'=>'mkfmshd',
        'st74cq46k'=>'mkfmshd',
        'zp38wc66m'=>'mkfmshd',
        'pv63g028j'=>'mkfmshd',
        'zp38wc67w'=>'mkfmshd',
        '1544bp163'=>'mkfmshd',
        '1z40ks82j'=>'mkfmshd',
        '2f75r803n'=>'mkfmshd',
        'd217qp51v'=>'mkfmshd',
        'sx61dm295'=>'mkfmshd',
        'x346d4229'=>'mkfmshd',
        '5h73pw09n'=>'mkfmshd',
        'x633f104m'=>'mkfmshd',
        '1z40ks83t'=>'mkfmshd',
        'x920fw877'=>'mkfmshd',
        'rj4304596'=>'mkfmshd',
        '5h73pw10d'=>'mkfmshd',
        '5m60qr961'=>'mkfmshd',
        'b5644r58h'=>'5wxz8l6',
        '8w32r569d'=>'5wxz8l6',
        'cv43nw890'=>'5wxz8l6',
        '7p88cg63m'=>'5wxz8l6',
        'nv935292q'=>'5wxz8l6',
        '4m90dv56d'=>'5wxz8l6',
        '79407x223'=>'5wxz8l6',
        '70795769f'=>'5wxz8l6',
        'mk61rh01q'=>'5wxz8l6',
        '6m311p359'=>'5wxz8l6',
        '6d56zw66p'=>'5wxz8l6',
        '44558d39p'=>'5wxz8l6',
        'k643b126w'=>'5wxz8l6',
        '3j333229t'=>'5wxz8l6',
        '5q47rn869'=>'5wxz8l6',
        'q237hs01r'=>'5wxz8l6',
        '1831cj962'=>'5wxz8l6',
        '1g05fc50d'=>'2fskon7',
        'zk51vh669'=>'2fskon7',
        'v118rf246'=>'2fskon7',
        'j3860693n'=>'dodh36q',
        'f7623c645'=>'dodh36q',
        'cv43nw865'=>'dodh36q',
        '4b29b601h'=>'dodh36q',
        'hd76s012n'=>'dodh36q',
        'ng451h55k'=>'dodh36q',
        '2j62s487q'=>'dodh36q',
        'm039k491c'=>'dodh36q',
        '8k71nh10x'=>'dodh36q',
        'vd66vz91p'=>'dodh36q',
        '8623hx75j'=>'1xk5evz',
        'db78tc05q'=>'1xk5evz',
        'v979v309v'=>'1xk5evz',
        'k930bx02c'=>'altvkck',
        'sf268514g'=>'altvkck',
        'h989r3271'=>'altvkck',
        't435gc99f'=>'altvkck',
        'hm50tr74r'=>'altvkck',
        '8g84mm27v'=>'altvkck',
        'qf85nb306'=>'altvkck',
        'sb397828k'=>'altvkck',
        '5425k972c'=>'altvkck',
        'ng451h531'=>'altvkck',
        'bv73c043w'=>'altvkck',
        '41687h46v'=>'altvkck'
      }
      changes = []
      errors = []
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          
          parents = {}
          adjustments.values.uniq.sort.each do |id|
            parent = Work.find_by_friendlier_id(id)
            if parent.nil?
              errors << "could not find parent id #{id}"
              next
            end
            parents[id] = parent
          end

          adjustments.keys.each do |id|
            errors << "could not find child id #{id}" if Work.find_by_friendlier_id(id).nil?
          end
          
          unless errors.present?
            progress_bar = ProgressBar.create(total: adjustments.keys.length, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
            Work.where(friendlier_id: adjustments.keys).find_each(batch_size: 10) do |child|
              parent_id = adjustments[child.friendlier_id]
              parent = parents[parent_id]
              if child.update(source: nil, parent: parent)
                changes << "Updated child #{child.friendlier_id} and assigned it parent #{parent.friendlier_id}"
              else
                errors << "Problem updating child #{child.friendlier_id}"
              end
              progress_bar.increment
            end
          end
        
        end
      end
      pp errors
      pp changes
    end
  end
end
