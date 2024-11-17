const path = require("path");
const webpack = require("webpack");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const FaviconsWebpackPlugin = require("favicons-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");
const Dotenv = require("dotenv-webpack");

module.exports = (env) => ({
  entry: "./src/frontend/index.js",
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "js/bundle.js",
    assetModuleFilename: "assets/[hash][ext][query]",
  },
  module: {
    rules: [
      {
        test: /\.(css|scss)$/,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: "css-loader",
          },
          {
            loader: "postcss-loader",
            options: {
              postcssOptions: {
                plugins: () => [require("autoprefixer")],
              },
            },
          },
          {
            loader: "sass-loader",
            options: { sourceMap: true },
          },
        ],
      },
      {
        test: /\.(woff|woff2|eot|ttf|otf)$/i,
        type: "asset/resource",
      },
      {
        test: /\.html$/,
        loader: "html-loader",
      },
    ],
  },
  plugins: [
    new Dotenv({
      path: `./.env.${env.local ? "local" : "production"}`,
    }),
    new webpack.DefinePlugin({
      API_HOST: JSON.stringify(env.local ? "" : "https://icp0.io"),
    }),
    new HtmlWebpackPlugin({
      inject: "body",
      title: "Cycle Express",
      template: "./src/frontend/index.html",
    }),
    new FaviconsWebpackPlugin({
      logo: "./src/frontend/logo.svg",
      mode: "webapp",
      favicons: {
        appName: "CycleExpress",
        appDescription: "Buy cycles with fiat",
        developerName: "Denotational Co",
        developerURL: "https://denotational.co",
        background: "#ddd",
        theme_color: "#333",
        start_url: "/",
        icons: {
          coast: false,
          yandex: false,
          windows: false,
          appleStartup: false,
        },
      },
    }),
    new MiniCssExtractPlugin({
      filename: "css/style.css",
    }),
    new CopyWebpackPlugin({
      patterns: [{ from: "./src/assets" }],
    }),
  ],
  devServer: {
    allowedHosts: "all",
    headers: { "Access-Control-Allow-Origin": "*" },
    hot: true,
    liveReload: true,
    server: "https",
    watchFiles: [path.resolve(__dirname, "src", "frontend")],
    proxy: [
      {
        context: ["/status"],
        target: "https://cycle.express",
        secure: false,
        changeOrigin: true,
      },
      {
        context: ["/api"],
        target: "https://icp0.io",
        secure: false,
        changeOrigin: true,
      },
    ],
  },
});
