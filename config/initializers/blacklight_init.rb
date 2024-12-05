

Rails.application.config.to_prepare do

  # by Emoji One
  # License: CC BY-SA 4.0(commercial use is allowed, attribution required)
  # https://icon-sets.iconify.design/emojione-v1/heavy-multiplication-x/
  Blacklight::Icons::RemoveComponent.svg = <<~EOS
    <svg xmlns="http://www.w3.org/2000/svg" width="0.9em" height="0.9em" viewBox="0 0 64 64"><path fill="currentColor" d="M49.692 3.956c-5.712 5.716-11.434 11.433-17.14 17.15q-8.574-8.571-17.15-17.15C8.788-2.655-1.46 7.598 5.151 14.209c5.714 5.711 11.433 11.431 17.14 17.14c-5.711 5.714-11.429 11.433-17.14 17.15c-6.611 6.609 3.642 16.859 10.251 10.252q8.57-8.575 17.15-17.15c5.716 5.717 11.428 11.431 17.14 17.15c6.612 6.608 16.861-3.643 10.255-10.251c-5.717-5.717-11.433-11.431-17.15-17.15q8.577-8.574 17.15-17.15c6.606-6.609-3.643-16.862-10.255-10.251"/></svg>
  EOS

end
