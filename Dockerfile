FROM ruby:3.3.5-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

ENV BUNDLE_PATH=/usr/local/bundle \
    RAILS_ENV=development

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENTRYPOINT ["bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
