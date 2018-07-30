#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    raw_members.each do |mem|
      mem[:party_id] ||= parties[mem[:party]]
    end
  end

  field :parties do
    @parties ||= raw_members.select { |mem| mem[:party_id] }.map { |mem| [ mem[:party], mem[:party_id] ] }.to_h
  end

  private

  def members_table
    noko.xpath('//table[.//th[contains(.,"Votos nominais")]]')
  end

  # parties are only links the first time they're mentioned. So we'll
  # need a second pass to add the Wikidata IDs for the others.
  def raw_members
    @raw_members ||= members_table.xpath('.//tr[td]').map { |tr| data = fragment(tr => MemberRow).to_h }
  end

end

class MemberRow < Scraped::HTML
  field :name do
    tds[0].css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    tds[0].css('a/@wikidata').map(&:text).first
  end

  field :party do
    tds[1].css('a').map(&:text).map(&:tidy).first || tds[1].xpath('text()').map(&:text).map(&:tidy).first
  end

  field :party_id do
    tds[1].css('a/@wikidata').map(&:text).first
  end

  field :area do
    tds[2].text.tidy
  end

  field :area do
    area_header.text
  end

  field :area_id do
    area_header.attr('wikidata')
  end

  private

  def tds
    noko.css('td')
  end

  def area_header
    noko.xpath('preceding::h3').last.css('.mw-headline a').last
  end
end

url = 'https://pt.wikipedia.org/wiki/Lista_de_deputados_federais_do_Brasil_da_55.%C2%AA_legislatura'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name area party])
