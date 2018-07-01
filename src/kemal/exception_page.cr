require "exception_page"

module Kemal
  class ExceptionPage < ExceptionPage
    def styles
      ExceptionPage::Styles.new(
        accent: "purple"
      )
    end

    def self.for_production_exception
      <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <style type="text/css">
          body { text-align:center;font-family:helvetica,arial;font-size:22px;
            color:#888;margin:20px}
          #c {margin:0 auto;width:500px;text-align:left}
          pre {text-align:left;font-size:14px;color:#fff;background-color:#222;
            font-family:Operator,"Source Code Pro",Menlo,Monaco,Inconsolata,monospace;
            line-height:1.5;padding:10px;border-radius:2px;overflow:scroll}
          </style>
        </head>
        <body>
          <h2>Kemal has encountered an error. (500)</h2>
          <p>Something wrong with the server :(</p>
        </body>
        </html>
      HTML
    end
  end
end
