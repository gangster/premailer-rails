require 'spec_helper'

describe Premailer::Rails::Hook do
  def run_hook(message)
    Premailer::Rails::Hook.delivering_email(message)
  end

  class Mail::Message
    def html_string
      (html_part || self).body.to_s
    end
  end

  let(:message) { Fixtures::Message.with_parts(:html) }
  let(:processed_message) { run_hook(message) }

  it 'inlines the CSS' do
    expect { run_hook(message) }.to \
      change { message.html_string.include?("<p style=") }
  end

  it 'replaces the html part with an alternative part containing text and html parts' do
    expect(processed_message.content_type).to include('multipart/alternative')
    expected_parts = [message.html_part, message.text_part]
    expect(processed_message.parts).to match_array(expected_parts)
  end

  it 'generates a text part from the html' do
    expect { run_hook(message) }.to change(message, :text_part)
  end

  context 'when message contains no html' do
    let(:message) { Fixtures::Message.with_parts(:text) }

    it 'does not modify the message' do
      expect { run_hook(message) }.to_not change(message, :html_string)
    end
  end

  context 'when message also contains a text part' do
    let(:message) { Fixtures::Message.with_parts(:html, :text) }

    it 'does not generate a text part' do
      expect { run_hook(message) }.to_not change(message, :text_part)
    end

    it 'does not replace any message part' do
      expect { run_hook(message) }.to_not \
        change { message.all_parts.map(&:content_type) }
    end
  end

  context 'when text generation is disabled' do
    it 'does not generate a text part' do
      begin
        Premailer::Rails.config[:generate_text_part] = false

        expect { run_hook(message) }.to_not change(message, :text_part)
      ensure
        Premailer::Rails.config[:generate_text_part] = true
      end
    end
  end

  context 'when message also contains an attachment' do
    let(:message) { Fixtures::Message.with_parts(:html, :attachment) }
    it 'does not mess with it' do
      expect(message.content_type).to include 'multipart/mixed'
      expect(message.parts.first.content_type).to include 'text/html'
      expect(message.parts.last.content_type).to include 'image/png'

      expect(processed_message.content_type).to include 'multipart/mixed'
      expect(processed_message.parts.first.content_type).to \
        include 'multipart/alternative'
      expect(processed_message.parts.last.content_type).to include 'image/png'
    end
  end

  context 'when message has a skip premailer header' do
    before do
      message.header[:skip_premailer] = true
    end

    it 'does not change the message body' do
      expect { run_hook(message) }.to_not change(message, :body)
    end

    it 'removes that header' do
      expect { run_hook(message) }.to \
        change { message.header[:skip_premailer].nil? }.to(true)
    end
  end
end
