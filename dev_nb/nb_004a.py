
        #################################################
        ### THIS FILE WAS AUTOGENERATED! DO NOT EDIT! ###
        #################################################
        # file to edit: dev_nb/004a_discriminative_lr.ipynb

from nb_004 import *

ModuleList = Collection[nn.Module]
ParamList = Collection[nn.Parameter]

bn_types = (nn.BatchNorm1d, nn.BatchNorm2d, nn.BatchNorm3d)

def requires_grad(l:nn.Module, b:Optional[bool]=None)->Optional[bool]:
    "If b is not set requires_grad on all params in l, else return requires_grad of first param"
    ps = list(l.parameters())
    if not ps: return None
    if b is None: return ps[0].requires_grad
    for p in ps: p.requires_grad=b

def trainable_params(m:nn.Module)->ParamList:
    "Return list of trainable params in `m`"
    res = filter(lambda p: p.requires_grad, m.parameters())
    return res

def split_bn_bias(layer_groups:ModuleList)->ModuleList:
    "Sort each layer in  `layer_groups` into batchnorm (`bn_types`) and non-batchnorm groups"
    split_groups = []
    for l in layer_groups:
        l1,l2 = [],[]
        for c in l.children():
            if isinstance(c, bn_types): l2.append(c)
            else:                       l1.append(c)
        split_groups += [nn.Sequential(*l1), nn.Sequential(*l2)]
    return split_groups

class OptimWrapper():
    "Basic wrapper around an optimizer to simplify HP changes"
    def __init__(self, opt:optim.Optimizer, wd:Floats=0., true_wd:bool=False, bn_wd:bool=True)->None:
        self.opt,self.true_wd,self.bn_wd = opt,true_wd,bn_wd
        self.opt_keys = list(self.opt.param_groups[0].keys())
        self.opt_keys.remove('params')
        self.read_defaults()
        self.wd = wd

    @classmethod
    def create(cls, opt_fn:Union[type,Callable], lr:Union[float,Tuple,List],
               layer_groups:ModuleList, **kwargs:Any)->optim.Optimizer:
        "Create an optim.Optimizer from `opt_fn` with `lr`. Set lr on `layer_groups``"
        split_groups = split_bn_bias(layer_groups)
        opt = opt_fn([{'params': trainable_params(l), 'lr':0} for l in split_groups])
        opt = cls(opt, **kwargs)
        opt.lr = listify(lr, layer_groups)
        return opt

    def __repr__(self)->str:
        return f'OptimWrapper over {repr(self.opt)}.\nTrue weight decay: {self.true_wd}'

    #Pytorch optimizer methods
    def step(self)->None:
        "Set weight decay and step optimizer"
        # weight decay outside of optimizer step (AdamW)
        if self.true_wd:
            for lr,wd,pg1,pg2 in zip(self._lr,self._wd,self.opt.param_groups[::2],self.opt.param_groups[1::2]):
                for p in pg1['params']: p.data.mul_(1 - wd*lr)
                if self.bn_wd:
                    for p in pg2['params']: p.data.mul_(1 - wd*lr)
            self.set_val('weight_decay', listify(0, self._wd))
        self.opt.step()

    def zero_grad(self)->None:
        "Clear optimizer gradients"
        self.opt.zero_grad()

    #Hyperparameters as properties
    @property
    def lr(self)->float:
        "Get learning rate"
        return self._lr[-1]

    @lr.setter
    def lr(self, val:float)->None:
        "Set learning rate"
        self._lr = self.set_val('lr', listify(val, self._lr))

    @property
    def mom(self)->float:
        "Get momentum"
        return self._mom[-1]

    @mom.setter
    def mom(self, val:float)->None:
        "Set momentum"
        if 'momentum' in self.opt_keys: self.set_val('momentum', listify(val, self._mom))
        elif 'betas' in self.opt_keys:  self.set_val('betas', (listify(val, self._mom), self._beta))
        self._mom = listify(val, self._mom)

    @property
    def beta(self)->float:
        "get beta"
        return None if self._beta is None else self._beta[-1]

    @beta.setter
    def beta(self, val:float)->None:
        "Set beta (or alpha as makes sense for give optimizer)"
        if val is None: return
        if 'betas' in self.opt_keys:    self.set_val('betas', (self._mom, listify(val, self._beta)))
        elif 'alpha' in self.opt_keys:  self.set_val('alpha', listify(val, self._beta))
        self._beta = listify(val, self._beta)

    @property
    def wd(self)->float:
        "Get weight decay"
        return self._wd[-1]

    @wd.setter
    def wd(self, val:float)->None:
        "Set weight decay"
        if not self.true_wd: self.set_val('weight_decay', listify(val, self._wd), bn_groups=self.bn_wd)
        self._wd = listify(val, self._wd)

    #Helper functions
    def read_defaults(self)->None:
        "Read the values inside the optimizer for the hyper-parameters"
        self._beta = None
        if 'lr' in self.opt_keys: self._lr = self.read_val('lr')
        if 'momentum' in self.opt_keys: self._mom = self.read_val('momentum')
        if 'alpha' in self.opt_keys: self._beta = self.read_val('alpha')
        if 'betas' in self.opt_keys: self._mom,self._beta = self.read_val('betas')
        if 'weight_decay' in self.opt_keys: self._wd = self.read_val('weight_decay')

    def set_val(self, key:str, val:Any, bn_groups:bool=True)->Any:
        "Set the values inside the optimizer dictionary at the key"
        if is_tuple(val): val = [(v1,v2) for v1,v2 in zip(*val)]
        for v,pg1,pg2 in zip(val,self.opt.param_groups[::2],self.opt.param_groups[1::2]):
            pg1[key] = v
            if bn_groups: pg2[key] = v
        return val

    def read_val(self, key:str) -> Union[List[float],Tuple[List[float],List[float]]]:
        "Read a hyper-parameter key in the optimizer dictionary."
        val = [pg[key] for pg in self.opt.param_groups[::2]]
        if is_tuple(val[0]): val = [o[0] for o in val], [o[1] for o in val]
        return val

def children(m:nn.Module)->ModuleList:
    "Get children of module"
    return list(m.children())
def num_children(m:nn.Module)->int:
    "Get number of child modules in module"
    return len(children(m))
def range_children(m:nn.Module)->Iterator[int]:
    "Return iterator of len of children of m"
    return range(num_children(m))

flatten_model=lambda l: sum(map(flatten_model,l.children()),[]) if num_children(l) else [l]
def first_layer(m:nn.Module)->nn.Module:
    "Retrieve first layer in a module"
    return flatten_model(m)[0]

def split_model_idx(model:nn.Module, idxs:Collection[int])->ModuleList:
    "Split the model according to the indices in [idxs]"
    layers = flatten_model(model)
    if idxs[0] != 0: idxs = [0] + idxs
    if idxs[-1] != len(layers): idxs.append(len(layers))
    return [nn.Sequential(*layers[i:j]) for i,j in zip(idxs[:-1],idxs[1:])]

def split_model(model:nn.Module, splits:Collection[ModuleList], want_idxs:bool=False):
    "Split the model according to the layers in [splits]"
    layers = flatten_model(model)
    idxs = [layers.index(first_layer(s)) for s in listify(splits)]
    res = split_model_idx(model, idxs)
    return (res,idxs) if want_idxs else res

bn_types = (nn.BatchNorm1d, nn.BatchNorm2d, nn.BatchNorm3d)

def set_bn_eval(m:nn.Module)->None:
    "Set bn layers in eval mode for all recursive children of m"
    for l in m.children():
        if isinstance(l, bn_types) and not next(l.parameters()).requires_grad:
            l.eval()
        set_bn_eval(l)

@dataclass
class BnFreeze(Callback):
    "Set all bntypes layers in `learn` to eval() on_epoch_begin"
    learn:Learner
    def on_epoch_begin(self, **kwargs:Any)->None:
        "Put bn layers in eval mode on epoch_begin"
        set_bn_eval(self.learn.model)

def even_mults(start:float, stop:float, n:int)->np.ndarray:
    "Build evenly stepped schedule from start to stop in n steps"
    mult = stop/start
    step = mult**(1/(n-1))
    return np.array([start*(step**i) for i in range(n)])

default_lr = slice(3e-3)
default_wd = 1e-2


SplitFuncOrIdxList = Union[Callable, Collection[ModuleList]]
@dataclass
class Learner():
    "Object that wraps together some data, a model, a loss function and an optimizer"
    data:DataBunch
    model:nn.Module
    opt_fn:Callable=AdamW
    loss_fn:Callable=F.cross_entropy
    metrics:Collection[Callable]=None
    true_wd:bool=True
    bn_wd:bool=True
    wd:Floats=default_wd
    train_bn:bool=True
    path:str = None
    model_dir:str = 'models'
    callback_fns:Collection[Callable]=None
    callbacks:Collection[Callback]=field(default_factory=list)
    layer_groups:Collection[nn.Module]=None
    def __post_init__(self)->None:
        "Setup path,metrics, callbacks and ensure model directory exists"
        self.path = Path(ifnone(self.path, self.data.path))
        (self.path/self.model_dir).mkdir(parents=True, exist_ok=True)
        self.model = self.model.to(self.data.device)
        self.metrics=listify(self.metrics)
        if not self.layer_groups: self.layer_groups = [nn.Sequential(*flatten_model(self.model))]
        self.callbacks = listify(self.callbacks)
        self.callback_fns = [Recorder] + listify(self.callback_fns)

    def lr_range(self, lr:Union[float,slice])->np.ndarray:
        "Build learning rate schedule"
        if not isinstance(lr,slice): return lr
        if lr.start: res = even_mults(lr.start, lr.stop, len(self.layer_groups))
        else: res = [lr.stop/3]*(len(self.layer_groups)-1) + [lr.stop]
        return np.array(res)

    def fit(self, epochs:int, lr:Union[Floats,slice]=default_lr,
            wd:Floats=None, callbacks:Collection[Callback]=None)->None:
        "fit the model on this learner with `lr` learning rate, `wd` weight decay for `epochs` with `callbacks`"
        lr = self.lr_range(lr)
        if wd is None: wd = self.wd
        self.create_opt(lr, wd)
        callbacks = [cb(self) for cb in self.callback_fns] + listify(callbacks)
        fit(epochs, self.model, self.loss_fn, opt=self.opt, data=self.data, metrics=self.metrics,
            callbacks=self.callbacks+callbacks)

    def create_opt(self, lr:Floats, wd:Floats=0.)->None:
        "create optimizer with `lr` learning rate and `wd` weight decay"
        self.opt = OptimWrapper.create(self.opt_fn, lr, self.layer_groups, wd=wd, true_wd=self.true_wd, bn_wd=self.bn_wd)

    def split(self, split_on:SplitFuncOrIdxList)->None:
        "split the model at `split_on`"
        if isinstance(split_on,Callable): self.layer_groups = split_on(self.model)
        else: self.layer_groups = split_model(self.model, split_on)

    def freeze_to(self, n:int)->None:
        "freeze layers up to layer `n`"
        for g in self.layer_groups[:n]:
            for l in g:
                if not self.train_bn or not isinstance(l, bn_types): requires_grad(l, False)
        for g in self.layer_groups[n:]: requires_grad(g, True)

    def freeze(self)->None:
        "freeze up to last layer"
        assert(len(self.layer_groups)>1)
        self.freeze_to(-1)

    def unfreeze(self):
        "unfreeze entire model"
        self.freeze_to(0)
    def __del__(self): del(self.model, self.data)
    def save(self, name:PathOrStr):
        "save model with `name` to `self.model_dir`"
        torch.save(self.model.state_dict(), self.path/self.model_dir/f'{name}.pth')
    def load(self, name:PathOrStr):
        "load model `name` from `self.model_dir"
        self.model.load_state_dict(torch.load(self.path/self.model_dir/f'{name}.pth'))

def fit_one_cycle(learn:Learner, cyc_len:int,
                  max_lr:Union[Floats,slice]=default_lr, moms:Tuple[float,float]=(0.95,0.85),
                  div_factor:float=25., pct_start:float=0.3, wd:float=None, **kwargs)->None:
    "Fits a model following the 1cycle policy"
    max_lr = learn.lr_range(max_lr)
    cbs = [OneCycleScheduler(learn, max_lr, moms=moms, div_factor=div_factor,
                             pct_start=pct_start, **kwargs)]
    learn.fit(cyc_len, max_lr, wd=wd, callbacks=cbs)

Learner.fit_one_cycle = fit_one_cycle
Learner.lr_find = lr_find