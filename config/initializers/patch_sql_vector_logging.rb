# Our 3072-dimensional vectors used for LLM embeddings take up a lot of space
# if logged by ActiveRecord in development mode.
#
# It was difficult to figure out a way to filter them, this patch to
# ActiveRecord::LogSubscriber works for now!
#
# Filters out anything that looks like a loogged really long vector, like eg:
#
#     [-0.3433434,-0.76349045-e05, {3000 more of those}]
#
module FilterLongVectorFromSqlLogs
  def debug(msg=nil, &block)
    if msg
      # number in a vector might look like:
      # 0.1293487
      # -21.983739734
      # -0.24878434e-05
      #
      # Optionally with whitespace surrounding
      number_re = '\s*\-?\d+(\.\d+)?(e-\d+)?\s*'

      # at least 49 of em, forget about it.
      msg.gsub!(/\[(#{number_re},){49,}#{number_re}\]/, '[FILTERED VECTOR]')
    end

    super(msg, &block)
  end
end

ActiveRecord::LogSubscriber.prepend(FilterLongVectorFromSqlLogs)
