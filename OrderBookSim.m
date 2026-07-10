function fpz_cloud_v3
% FPZ_CLOUD_V3  Zero-intelligence limit-order-book animation with an emergent
%               candlestick chart (full width) and a live order-book cloud
%               inset (NW corner). Shows how support/resistance, the bid-ask
%               spread, and a quiet/pinned tape arise from random order flow
%               alone -- no news, no institutions, no intelligence.
%
% Each step draws one event: a limit order (rests in the book), a market
% order (consumes best-priced resting size, walking deeper if large), or a
% cancellation (proportional thinning). A fraction pCluster of new limits
% join existing depth (preferential attachment), sharpening diffuse liquidity
% into walls read on the chart as support and resistance. No placement clamp:
% price is a free random walk. Reproducible via the fixed seed rng(11).
%
% Outputs (current folder): fpz_cloud.mp4 (30 fps) and, if makeGIF, fpz_cloud.gif.
% Requires only base MATLAB (VideoWriter; GIF export uses rgb2ind/imwrite).

rng(11);

% ---------- palette ----------
BG  = [0.055 0.067 0.086];          % #0E1116
GRN = [0.00 1.00 0.53];
RED = [1.00 0.18 0.14];
AMB = [1.00 0.75 0.20];
GRY = [0.62 0.66 0.72];

% ---------- model knobs ----------
tick = 0.01;  P0 = 100.00;
winCloud = 0.55;                    % inset (cloud) half-height ($)
followA  = 0.02;                    % axis slow-follow rate per frame
band = P0 + [-0.45 0.45];           % initial SEED window only
sMax = 8;  N0 = 260;  nEv = 5400;
cancScale = 250;                    % proportional-cancellation divisor

% Event mix per step:  P(limit)=pLim, P(market)=pMkt, P(cancel)=1-pLim-pMkt.
%   W        uniform-limit placement band (ticks) when NOT joining a cluster
%   pCluster probability a new limit joins existing depth (preferential attach.)
%   winPx    candle-axis half-height ($) -- DISPLAY ONLY, no effect on dynamics
W        = 15;                      % narrow band -> fast replenishment at touch
pLim     = 0.65;  pMkt = 0.25;      % rest (0.10) = cancellations
pCluster = 0.35;
winPx    = 0.25;                    % pinned/quiet tape: small candles

% ---------- render knobs ----------
evPerFrame = 5;   evPerBar = 45;   fps = 30;   makeGIF = true;
areaK = 6;  xHalf = 1;              % smaller circles for the inset
insetPos = [0.095 0.63 0.17 0.29];  % NW corner [x y w h], normalized

% ---------- order store: [price size x side birth] ----------
O = zeros(0,5);
prices0 = band(1) + (band(2)-band(1))*rand(N0,1);
for k = 1:N0
    side = sign(P0 - prices0(k)); if side==0, side = 1; end
    O(end+1,:) = [roundTick(prices0(k),tick), randi(sMax), ...
        (2*rand-1)*xHalf*0.95, side, 0]; %#ok<AGROW>
end
last = P0;  price = nan(1,nEv);
nBars = ceil(nEv/evPerBar);

% ---------- figure ----------
sz = get(0,'ScreenSize');
FigPos = [0.05*sz(3) 0.1*sz(4) 0.9*sz(3) 0.8*sz(4)];
f = figure('Color',BG,'Position',FigPos,'Name','ZI order book — emergent S/R');

% main candle axes (full width)
axP = axes(f,'Position',[0.06 0.09 0.90 0.84]); hold(axP,'on');
styleAx(axP,BG,GRY); ytickformat(axP,'usd');
title(axP,sprintf('Price — 1 candle = %d events\nInset: resting orders, circle area = size', ...
    evPerBar),'Color',GRY,'FontSize',13,'FontWeight','bold');
xlabel(axP,'bar','Color',GRY);

hWickU = plot(axP,nan,nan,'-','Color',GRN,'LineWidth',1.0);
hWickD = plot(axP,nan,nan,'-','Color',RED,'LineWidth',1.0);
hBodyU = patch(axP,'Faces',[],'Vertices',[],'FaceColor',GRN,'EdgeColor','none');
hBodyD = patch(axP,'Faces',[],'Vertices',[],'FaceColor',RED,'EdgeColor','none');

% inset cloud axes (NW corner, drawn on top)
axC = axes(f,'Position',insetPos); hold(axC,'on');
styleAx(axC,BG,GRY); ytickformat(axC,'usd');
set(axC,'XTick',[],'FontSize',8,'LineWidth',0.5);
hAsk = scatter(axC,[],[],[],RED,'filled','MarkerFaceAlpha',0.80);
hBid = scatter(axC,[],[],[],GRN,'filled','MarkerFaceAlpha',0.80);
hPrn = scatter(axC,[],[],90,AMB,'LineWidth',1.5);
hBB  = yline(axC,P0,'-','Color',GRN,'LineWidth',0.6,'Alpha',0.45);
hBA  = yline(axC,P0,'-','Color',RED,'LineWidth',0.6,'Alpha',0.45);

ctr = P0;
xlim(axC,[-xHalf xHalf]*1.08); ylim(axC,ctr+[-winCloud winCloud]);
xlim(axP,[0 nBars+1]);         ylim(axP,P0+[-winPx winPx]);   % FIXED

vw = VideoWriter('fpz_cloud.mp4','MPEG-4'); vw.FrameRate = fps; open(vw);
gifName = 'fpz_cloud.gif'; firstGif = true;

nFr = ceil(nEv/evPerFrame);
for fr = 1:nFr
    prints = [];
    for e = 1:evPerFrame
        t = (fr-1)*evPerFrame + e; if t > nEv, break; end
        u  = rand;
        bb = bestPrice(O,+1); ba = bestPrice(O,-1);
        if isempty(bb), bb = last - tick; end
        if isempty(ba), ba = last + tick; end

        if u < pLim                                  % ---- new limit order
            s = randi(sMax);
            buySide = rand < 0.5;
            side = 1 - 2*~buySide;
            p = [];
            if rand < pCluster                       % JOIN existing depth
                c = find(O(:,4)==side);
                if ~isempty(c)
                    wgt = O(c,2); pick = c(randsample(numel(c),1,true,wgt));
                    p = O(pick,1);
                    if buySide, p = min(p, ba - tick);
                    else,       p = max(p, bb + tick); end
                end
            end
            if isempty(p)
                if buySide, p = ba - tick*randi(W);
                else,       p = bb + tick*randi(W); end
            end
            O(end+1,:) = [roundTick(p,tick), s, (2*rand-1)*xHalf*0.95, side, t]; %#ok<AGROW>
        elseif u < pLim + pMkt                       % ---- market order
            s = randi(sMax);
            aggBuy = rand < 0.5;
            while s > 0
                if aggBuy, [pB,ix] = bestRow(O,-1,'min');
                else,      [pB,ix] = bestRow(O,+1,'max'); end
                if isempty(ix), break; end
                take = min(s, O(ix,2));
                O(ix,2) = O(ix,2) - take;  s = s - take;
                last = pB;  prints(end+1) = pB; %#ok<AGROW>
                if O(ix,2) <= 0, O(ix,:) = []; end
            end
        else                                         % ---- cancellation
            nDel = min(size(O,1), max(1, round(size(O,1)/cancScale)));
            for d = 1:nDel
                O(randi(size(O,1)),:) = [];
            end
        end
        price(t) = last;
    end

    % ------- render: inset cloud -------
    isB = O(:,4) > 0;
    set(hBid,'XData',O(isB,3), 'YData',O(isB,1), 'SizeData',areaK*O(isB,2));
    set(hAsk,'XData',O(~isB,3),'YData',O(~isB,1),'SizeData',areaK*O(~isB,2));
    set(hPrn,'XData',zeros(1,numel(unique(prints))),'YData',unique(prints));
    bb = bestPrice(O,+1); ba = bestPrice(O,-1);
    if ~isempty(bb), hBB.Value = bb; end
    if ~isempty(ba), hBA.Value = ba; end

    % ------- render: candles -------
    tNow = min(fr*evPerFrame,nEv);
    kBar = ceil(tNow/evPerBar);
    Vu = zeros(0,2); Fu = zeros(0,4);
    Vd = zeros(0,2); Fd = zeros(0,4);
    [wxu,wyu,wxd,wyd] = deal([]);
    hw = 0.32;  minBody = 0.6*tick;
    for b = 1:kBar
        seg = price((b-1)*evPerBar+1 : min(b*evPerBar,tNow));
        seg = seg(~isnan(seg)); if isempty(seg), continue; end
        o = seg(1); c = seg(end); h = max(seg); l = min(seg);
        up = c >= o;
        yLo = min(o,c); yHi = max(o,c);
        if yHi - yLo < minBody
            m = (yLo+yHi)/2; yLo = m - minBody/2; yHi = m + minBody/2;
        end
        V = [b-hw yLo; b+hw yLo; b+hw yHi; b-hw yHi];
        wx = [b b NaN];  wy = [l h NaN];
        if up
            Fu(end+1,:) = size(Vu,1) + (1:4); Vu = [Vu; V]; %#ok<AGROW>
            wxu = [wxu wx]; wyu = [wyu wy];                 %#ok<AGROW>
        else
            Fd(end+1,:) = size(Vd,1) + (1:4); Vd = [Vd; V]; %#ok<AGROW>
            wxd = [wxd wx]; wyd = [wyd wy];                 %#ok<AGROW>
        end
    end
    set(hBodyU,'Faces',Fu,'Vertices',Vu);
    set(hBodyD,'Faces',Fd,'Vertices',Vd);
    set(hWickU,'XData',wxu,'YData',wyu); set(hWickD,'XData',wxd,'YData',wyd);

    ctr = (1-followA)*ctr + followA*last;
    ylim(axC, ctr+[-winCloud winCloud]);          % inset follows; candles fixed

    drawnow;
    frame = getframe(f);
    writeVideo(vw,frame);
    if makeGIF && mod(fr,2)==1
        [A,map] = rgb2ind(frame2im(frame),256);
        if firstGif
            imwrite(A,map,gifName,'gif','LoopCount',Inf,'DelayTime',2/fps);
            firstGif = false;
        else
            imwrite(A,map,gifName,'gif','WriteMode','append','DelayTime',2/fps);
        end
    end
end
close(vw);
fprintf('Wrote fpz_cloud.mp4%s\n', ternary(makeGIF,' and fpz_cloud.gif',''));
end

% ---------- helpers ----------
function p = roundTick(p,tick), p = round(p/tick)*tick; end

function p = bestPrice(O,side)
p = [];
ix = O(:,4)==side;
if any(ix)
    if side>0, p = max(O(ix,1)); else, p = min(O(ix,1)); end
end
end

function [pBest,ix] = bestRow(O,side,mode)
pBest = []; ix = [];
c = find(O(:,4)==side);
if isempty(c), return; end
if strcmp(mode,'min'), pBest = min(O(c,1)); else, pBest = max(O(c,1)); end
c = c(O(c,1)==pBest);
[~,k] = min(O(c,5));
ix = c(k);
end

function s = ternary(c,a,b), if c, s=a; else, s=b; end, end

function styleAx(ax,BG,GRY)
set(ax,'Color',BG,'XColor',GRY,'YColor',GRY, ...
    'GridColor',GRY,'GridAlpha',0.10,'Box','off','FontSize',10);
grid(ax,'on');
end
